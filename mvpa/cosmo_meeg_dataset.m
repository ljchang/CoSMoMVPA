function ds=cosmo_meeg_dataset(filename, varargin)
% Returns a dataset structure based on MEEG data
%
% ds=cosmo_meeg_dataset(filename, varargin)
%
% Inputs:
%   filename          filename of MEEG data to be loaded. Currently this
%                     can be a .mat file (for FieldTrip) with timelocked or
%                     time-frequency data, or .txt (exported EEGLab) for
%                     timelocked data. Alternatively it can be a FieldTrip
%                     struct with timelocked or time-frequency data.
%   'targets', t      Px1 targets for P samples; these will be stored in
%                     the output as ds.sa.targets
%   'chunks', c       Px1 chunks for P samples; these will be stored in the
%                     the output as ds.sa.chunks
%
% Returns:
%   ds                dataset struct with the following fields
%     .samples        PxQ for P samples and Q features.
%     .sa.targets     Px1 sample targets (if provided)
%     .sa.chunks      Px1 sample chunks (if provided)
%     .a
%       .hdr_{F}           header information for format F. Currently
%                          F is always 'ft'.
%       .meeg
%         .sample_field   name of sample field. One of 'fourierspctrm',
%                         'powspctrm', or 'trial'.
%         .samples_type   'timelock' or 'timefreq'.
%         .samples_label  Usually 'rpt'; or the first field of .dimord
%                         for FieldTrip data
%       .dim
%         .labels     1xS cell struct with labels for the feature
%                     dimensions of the input. Usually this is
%                     {'chan','time'} or {'chan','freq','time'}.
%         .values     1xS cell struct with values associated with .labels.
%                     If the K-th value has N_K values, this means that
%                     the feature dimension .labels{K} takes the
%                     values in .values{K}. For example, if
%                     .labels{1}=='chan', then .values{1} contains the
%                     channel labels.
%     .fa
%       .{D}          if D==a.fdim.labels{K} is the label for the K-th
%                     feature dimension, then .{D} contains the
%                     indices referencing a.fdim.values. Thus, all values in
%                     .{D} are in the range 1:N_K if a.fdim.values{K} has
%                     N_K values, and the J-th feature has dimension value
%                     .dim.values{K}(.{D}(J)) in the K-th dimension.
%
% Notes:
%  - The resulting dataset can be mapped back to MEEG format using
%    cosmo_map2meeg.
%  - if the input contains data from a single sample (such as an average)
%    the .sample_field is set to .trial, and mapping back to MEEG format
%    adds a singleton dimension to the .trial data output field.
%  - Most MVPA applications require that .sa.targets (experimental
%    condition of each sample) and .sa.chunks (partitioning of the samples
%    in independent sets) are set, either by using this function or
%    manually afterwards.
%
% Dependency:
%  - Loading Fieldtrip structures requires the FieldTrip toolbox:
%      http://http://fieldtrip.fcdonders.nl
%
% See also: cosmo_map2meeg
%
% NNO Sep 2013

    % Input parsing stuff

    defaults=struct();
    defaults.targets=[];
    defaults.chunks=[];

    params = cosmo_structjoin(defaults, varargin);

    if cosmo_check_dataset(filename,'meeg',false)
        % it is already a dataset, so return it
        ds=filename;
        return
    end

    % get image format and verify it is supported
    img_format=get_img_format(filename);
    supported_image_formats=get_supported_image_formats();

    % check externals
    cosmo_check_external(supported_image_formats.(img_format).externals);

    % get the reader
    reader=supported_image_formats.(img_format).reader;

    % read the dataset
    ds=reader(filename);

    % set targets and chunks
    ds=set_vec_sa(ds,'targets',params.targets);
    ds=set_vec_sa(ds,'chunks',params.chunks);


    % check consistency
    cosmo_check_dataset(ds,'meeg');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% general helper functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ds=set_vec_sa(ds, label, values)
    if isempty(values)
        return;
    end
    if numel(values)==1
        nsamples=size(ds.samples,1);
        values=repmat(values,nsamples,1);
    end
    ds.sa.(label)=values(:);


function img_format=get_img_format(filename)
    % helper functgion to detect image format based on filename.
    % uses 'get_supported_image_formats'.
    img_formats=get_supported_image_formats();

    fns=fieldnames(img_formats);
    for k=1:numel(fns)
        fn=fns{k};

        img_spec=img_formats.(fn);
        if img_spec.file_matcher(filename)
            img_format=fn;
            return
        end
    end
    error('Unknown image format');

function img_formats=get_supported_image_formats()
    % helper function to return the image format based on the filename
    img_formats=struct();

    % helper function to see if a filename ends with a certain string.
    % uses currying - who doesn't like curry?
    endswith=@(ext) @(fn) ischar(fn) && isempty(cosmo_strsplit(fn,ext,-1));

    % eeglab txt files
    img_formats.eeglab_txt.file_matcher=endswith('.txt');
    img_formats.eeglab_txt.reader=@read_eeglab_txt;
    img_formats.eeglab_txt.externals={};

    % fieldtrip
    % XXX any .mat file is currently assumed to be a fieldtrip struct
    img_formats.ft.file_matcher=endswith('.mat');
    img_formats.ft.reader=@read_ft;
    img_formats.ft.externals={'fieldtrip'};

    % fieldtrip matlab struct
    img_formats.ft_struct.file_matcher=@(x) isstruct(x) && ...
                                ~strcmp('unknown',isempty(ft_datatype(x)));
    img_formats.ft_struct.reader=@convert_ft;
    img_formats.ft_struct.externals={'fieldtrip'};




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fieldtrip helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ds=read_ft(filename)
    % reads it from a .mat data file
    ft=importdata(filename);
    ds=convert_ft(ft);

function tp=ft_senstype_wrapper(ft)
    % wrapper to deal with neuromag306
    tp=ft_senstype(ft);
    if strcmp(tp,'unknown')
        label=ft.label;
        m=~cellfun(@isempty,regexp(label,'MEG.\d\d\d'));

        if mean(m)>.4
            tp='neuromag';
        end
    end


function ds=convert_ft(ft)
    % ft is a fieldtrip struct
    datatype=ft_datatype(ft);
    senstype=ft_senstype_wrapper(ft);

    % smallish hack: timelock data with 'avg' data is only 2D, but
    % must be transformed to 3D with singleton dimension before
    % flattening it to a 2D (row-vector) array.
    set_samples_field=[];
    switch datatype
        case 'freq'
            % see in which field the data is stored
            sample_fields={'fourierspctrm','powspctrm'};
            expected_dim_labels={'chan','freq','time'};

        case 'timelock'
            % order is important - first 'trial' (means single trial data),
            % if absent check for 'avg'.
            sample_fields={'trial','avg'};
            expected_dim_labels={'chan','time'};
            set_samples_field='trial';

        otherwise
            error('unsupported fieldtrip datatype: %s', datatype);
    end

    samples_arr=[];
    for k=1:numel(sample_fields)
        samples_field=sample_fields{k};
        if isfield(ft, samples_field)
            samples_arr=ft.(samples_field);
            ft=rmfield(ft,samples_field);

            % apply hack - override the samples field
            if ~isempty(set_samples_field)
                samples_field=set_samples_field;
            end
            break
        end
    end

    if isempty(samples_arr), error('Could not find sample data'); end

    % get the dimension labels
    dim_labels=cosmo_strsplit(ft.dimord,'_');

    % See if the first dimension is a dimension label (chan, freq, time).
    insert_sample_dim=cosmo_match(dim_labels(1),expected_dim_labels);

    %expected_ndim=numel(expected_dim_labels)+1;
    %insert_sample_dim=ndim==expected_ndim-1;

    sa=struct(); % space for sample attributes
    if insert_sample_dim
        nsamples=1;
        % one dimension short - add one at first position
        samples_arr=reshape(samples_arr,[nsamples size(samples_arr)]);
        % let's call it a repeat
        samples_label='rpt';
    else
        % proper number of dimensions
        nsamples=size(samples_arr,1);
        sa.(dim_labels{1})=(1:nsamples)'; % set sample attribute
        samples_label=dim_labels{1};
    end

    % get the dim labels - they should match expected_dim_labels
    % if add_dim then start at first label, otherwise at second.
    dim_labels=dim_labels((1+~insert_sample_dim):end);
    nfeature_dim_expected=numel(dim_labels);

    % check the labels
    if ~isempty(setdiff(dim_labels,expected_dim_labels))
        delta=setdiff(dim_labels,expected_dim_labels);
        error('unexpected field %s in .dimord %s', delta{1}, ft.dimord);
    end

    nfeature_dim=numel(size(samples_arr))-1; % number of feature dimensions
    if nfeature_dim~=nfeature_dim_expected
        error('Found %d dimensions, expected %d from .dimord (%s)',...
                    nfeature_dim, nfeature_dim_expected, ft.dimord);
    end

    % store values for each feature dimensions, e.g. labels of the
    % channels, onets for time, and frequency for freq
    dim_values=cell(1,nfeature_dim);
    for k=1:nfeature_dim
        dim_label=dim_labels{k};
        if strcmp(dim_label,'chan')
            % FT uses label to refer to channel names
            dim_label='label';
        end
        dim_value=ft.(dim_label);
        dim_values{k}=dim_value(:);
    end

    % make a dataset
    ds=cosmo_flatten(samples_arr, dim_labels, dim_values);

    % store as attribtues
    ds.a.meeg.samples_field=samples_field;
    ds.a.meeg.samples_type=datatype;
    ds.a.meeg.samples_label=samples_label;

    if ~strcmp(senstype,'unknown')
        ds.a.meeg.senstype=senstype;
    end

    ds.sa=sa;
    if isfield(ft,'trialinfo')
        ds.sa.trialinfo=ft.trialinfo;
    end

    if isfield(ft,'cumtapcnt') && size(ft.cumtapcnt,1)==nsamples
        ds.sa.cumtapcnt=ft.cumtapcnt;
    end






%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eeglab helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ds=read_eeglab_txt(fn)
    % reads eeglab time series data. returns data in fieldtrip-like format
    fid=fopen(fn);

    header_line=fgetl(fid); % read header
    chan_labels=cosmo_strsplit(header_line,'\t');
    chan_labels=chan_labels(2:(end-1)); % omit first & last bogus element

    nchan=numel(chan_labels);
    data_pat=cosmo_strjoin(repmat({'%n'},1,nchan+1),'\t');

    % read data from file
    cell_data=textscan(fid,data_pat);

    % check all data was read
    neg_one=fgetl(fid);
    fgetl(fid);
    if neg_one~=-1
        error('Could not read all data from %s', fn);
    end

    %%%%%%%%%%%%%%%
    % data consistency checks

    % timepoints are in the first column, data in other columns
    timepoints=cell_data{1};
    nrows=numel(timepoints);

    % check that timepoints are increasing for each trial, and repeating
    t_start=min(timepoints);
    t_end=max(timepoints);

    pos_start=find(timepoints==t_start,1,'first');
    pos_end=find(timepoints==t_end,1,'first');

    % onsets of the first trial
    t_trial=timepoints(pos_start:pos_end);

    % number of timepoints per trial
    ntime=numel(t_trial);

    % number of trials
    ntrial=nrows/ntime;

    % ensure time points are set properly
    if pos_start~=1 || round(ntrial)~=ntrial || ...
            ~isequal(repmat(t_trial,ntrial,1), timepoints)
        error('Data not contiguous or unexpected order of time points');
    end


    %%%%%%%%%%%%%%%
    % put the data in 3D array
    data=zeros(ntrial,nchan,ntime);
    for chan=1:nchan
        chan_data=cell_data{chan+1}; % skip first column as it has timepoints
        data(:,chan,:)=reshape(chan_data,ntime,ntrial)';
    end

    %%%%%%%%%%%%%%%
    % flatten and make it a dataset
    % (convert miliseconds to seconds along the way)
    dim_labels={'chan','time'};
    dim_values={chan_labels, .001*t_trial'};

    % make a dataset
    ds=cosmo_flatten(data, dim_labels, dim_values);

    % set datatype to timelock-ish in fieldtrip-compatible way
    ds.a.meeg.samples_field='trial';
    ds.a.meeg.samples_type='timelock';
    ds.a.meeg.samples_label='rpt';

    % set sample info
    ds.sa.(ds.a.meeg.samples_label)=(1:ntrial)';

