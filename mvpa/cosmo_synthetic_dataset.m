function ds=cosmo_synthetic_dataset(varargin)
% generate synthetic dataset
%
% ds=cosmo_synthetic_dataset(varargin)
%
% Inputs:
%   'size', s               determines the number of features. One of
%                           'tiny', 'small', 'normal', 'big', or 'huge'
%   'type', t               type of dataset. One of 'fmri', 'meeg',
%                           'timelock', 'timefreq', 'surface'. 'meeg' is
%                           equivalent to 'timelock'
%   'sens', c               for meeg datasets ('time{lock}, 'meeg'), this
%                           sets which sensor type is used. Supported are
%                           - neuromag306{all,planar,combined,mag}
%                           - ctf151
%                           - 4d{1,2}48[planar]
%                           - yokogawa{64,160}[planar]
%                           - eeg10{05,10,20}
%   'sigma', sigma          parameter to influence class distance. The
%                           larger this value, the more discrimable the
%                           classes are.
%
%   'ntargets', nt          number of unique targets (default: 2)
%   'nchunks', nc           number of unique chunks (default: 3)
%
%   'nmodalities', nm       number of unique modalities (default: [])
%   'nsubjects', ns         number of unique subjects (default: [])
%   'nreps', nr             number of sample repeats (default: [])
%
% Output:
%    ds                     dataset struct according to parameters.
%                           The output has (nt*nc*nm*ns*nr) samples, and
%                           the number of features is determined by s.
%                           If any of the nt, nc, nm, ns, nr values are not
%                           empty, there is a corresponding sample
%                           attribute.
%
% Examples:
%    ds=cosmo_synthetic_dataset();
%    cosmo_disp(ds);
%     > .samples
%     >   [   2.21    -0.434     0.725      3.08     0.489     0.888
%     >       1.83      2.02   -0.0631      1.42      2.71     -1.15
%     >     -0.585      3.58     0.715      2.35     0.727     -1.07
%     >      0.862      4.44    -0.205     -1.21      1.37    -0.809
%     >       1.99     -1.35    -0.124      2.39     0.294     -2.94
%     >      -1.31      4.71      1.49      1.63     0.887      1.44 ]
%     > .fa
%     >   .i
%     >     [ 1         2         3         1         2         3 ]
%     >   .j
%     >     [ 1         1         1         2         2         2 ]
%     >   .k
%     >     [ 1         1         1         1         1         1 ]
%     > .a
%     >   .fdim
%     >     .labels
%     >       { 'i'  'j'  'k' }
%     >     .values
%     >       { [ 1         2         3 ]  [ 1         2 ]  [ 1 ] }
%     >   .vol
%     >     .mat
%     >       [ 10         0         0         0
%     >          0        10         0         0
%     >          0         0        10         0
%     >          0         0         0         1 ]
%     >     .dim
%     >       [ 3         2         1 ]
%     > .sa
%     >   .targets
%     >     [ 1
%     >       2
%     >       1
%     >       2
%     >       1
%     >       2 ]
%     >   .chunks
%     >     [ 1
%     >       1
%     >       2
%     >       2
%     >       3
%     >       3 ]
%
%     ds=cosmo_synthetic_dataset('sigma',5,'type','timefreq',...
%                                'nchunks',5,'ntargets',4,'size','huge',...
%                                'nsubjects',10);
%     cosmo_disp(ds)
%     > .samples
%     >   [ 0.972     0.183      0.27  ...  -0.477     -1.12     0.127
%     >      1.83    -0.595     0.494  ...  -0.663     0.517    -0.167
%     >     -2.26     0.949     -1.05  ...    0.67    -0.449    -0.511
%     >       :         :         :            :         :         :
%     >     0.467      1.04     0.551  ...  -0.557      1.01     0.211
%     >     -0.21    -0.118      1.12  ...  -0.454     -1.12        -1
%     >     0.625     0.699      1.17  ...   -1.93    0.0967     0.606 ]@200x98838
%     > .fa
%     >   .chan
%     >     [ 1         2         3  ...  304       305       306 ]@1x98838
%     >   .freq
%     >     [ 1         1         1  ...  17        17        17 ]@1x98838
%     >   .time
%     >     [ 1         1         1  ...  19        19        19 ]@1x98838
%     > .a
%     >   .fdim
%     >     .labels
%     >       { 'chan'  'freq'  'time' }
%     >     .values
%     >       { { 'MEG0111'          [  2         [  -0.2
%     >           'MEG0112'             4           -0.15
%     >           'MEG0113'             6            -0.1
%     >              :                  :             :
%     >           'MEG2641'            30             0.6
%     >           'MEG2642'            32            0.65
%     >           'MEG2643' }@306x1    34 ]@17x1      0.7 ]@19x1 }
%     >   .meeg
%     >     .samples_type
%     >       'freq'
%     >     .samples_field
%     >       'powspctrm'
%     >     .samples_label
%     >       'rpt'
%     > .sa
%     >   .targets
%     >     [ 1
%     >       2
%     >       3
%     >       :
%     >       2
%     >       3
%     >       4 ]@200x1
%     >   .chunks
%     >     [ 1
%     >       1
%     >       1
%     >       :
%     >       5
%     >       5
%     >       5 ]@200x1
%     >   .subject
%     >     [  1
%     >        1
%     >        1
%     >        :
%     >       10
%     >       10
%     >       10 ]@200x1
%
%     % example of MEEG dataset with ctf151 layout
%     ds=cosmo_synthetic_dataset('type','meeg',...
%                                   'sens','ctf151','size','huge');
%     % show labels and values for feature dimensions
%     cosmo_disp(ds.a.fdim)
%     > .labels
%     >   { 'chan'  'time' }
%     > .values
%     >   { { 'MLC11'          [  -0.2
%     >       'MLC12'            -0.15
%     >       'MLC13'             -0.1
%     >         :                  :
%     >       'MZO02'              0.5
%     >       'MZP01'             0.55
%     >       'MZP02' }@151x1      0.6 ]@17x1 }
%
%     % example of MEEG dataset with 4d148 layout (3 channels only)
%     ds=cosmo_synthetic_dataset('type','meeg','sens','4d148_planar');
%     cosmo_disp(ds.a.fdim)
%     > .labels
%     >   { 'chan'  'time' }
%     > .values
%     >   { { 'A148_dH'    [  -0.2
%     >       'A147_dH'      -0.15 ]
%     >       'A146_dH' }            }
%
% NNO Aug 2014

    default=struct();
    default.ntargets=2;
    default.nchunks=3;

    default.sigma=3;
    default.size='small';
    default.type='fmri';

    default.nreps=[];
    default.nmodalities=[];
    default.nsubjects=[];
    default.chunks=[];
    default.targets=[];

    default.target1=1;

    % for MEEG
    default.sens='neuromag306_all';

    opt=cosmo_structjoin(default,varargin);

    [ds, nfeatures]=get_fdim_fa(opt);

    sa_labels_pl={'ntargets','nchunks','nmodalities','nsubjects','nreps'};
    cp=cosmo_cartprod(cellfun(@(x)1:max([opt.(x) 1]),sa_labels_pl,...
                                            'UniformOutput',false));
    sa_labels_si={'targets','chunks','modality','subject','rep'};
    for k=1:numel(sa_labels_si)
        if ~isempty(opt.(sa_labels_pl{k}))
            ds.sa.(sa_labels_si{k})=cp(:,k);
        end
    end


    nelem=log(nfeatures*max([opt.nreps 1]));
    class_distance=opt.sigma/nelem;

    ds.samples=generate_samples(ds, class_distance);
    ds=assign_sa(ds, opt, {'chunks','targets'});

    ds.sa.targets=ds.sa.targets+opt.target1-1;

    cosmo_check_dataset(ds);

function ds=assign_sa(ds, opt, names)
    nsamples=size(ds.samples,1);

    for k=1:numel(names)
        name=names{k};
        v=opt.(name);
        if ~isempty(v)
            if ~isscalar(v)
                error('Value for ''%s'' must be a scalar', name);
            end
            ds.sa.(name)=ones(nsamples,1)*v;
        end
    end


function samples=generate_samples(ds, class_distance)

    targets=ds.sa.targets;
    nsamples=numel(targets);
    nclasses=numel(unique(targets));

    fa_names=fieldnames(ds.fa);
    nfeatures=numel(ds.fa.(fa_names{1}));

    if cosmo_wtf('is_matlab')
        rng_state=rng();
        c=onCleanup(@()rng(rng_state));
        rng('default');
    else
        % Note: this gives a different RNG state than Matlab
        % For unit and doc testing this may be bad
        rng_state=randn('state');
        c=onCleanup(@()randn('state',rng_state));
        randn('seed',0);
    end

    samples=randn(nsamples,nfeatures);

    add_msk=mod(bsxfun(@minus,1:nclasses+1,targets),nclasses+1)==0;
    add_msk_full=repmat(add_msk,1,ceil(nfeatures/(nclasses+1)));
    add_msk_full=add_msk_full(:,1:nfeatures);
    samples(add_msk_full)=samples(add_msk_full)+class_distance;

function a=dim_labels_values(opt)
    data_type=opt.type;
    sens_type=opt.sens;

    a=struct();

    switch data_type
        case 'fmri'
            a.vol.mat=eye(4);
            a.vol.mat(1:3,1:3)=a.vol.mat(1:3,1:3)*10;

            labels={'i','j','k'};
            values={1:20,1:20,1:20};

        case {'meeg','timelock','timefreq'}
            % simulate full neuromag 306 system
            chan=get_meeg_channels(sens_type);

            time=(-.2:.05:1.3)';

            switch data_type
                case 'timefreq'
                    freq=(2:2:40)';
                    values={chan,freq,time};
                    labels={'chan','freq','time'};
                    a.meeg.samples_type='freq';
                    a.meeg.samples_field='powspctrm';

                otherwise % meeg and timelock
                    values={chan,time};
                    labels={'chan','time'};
                    a.meeg.samples_type='timelock';
                    a.meeg.samples_field='trial';
            end

            a.meeg.samples_label='rpt';

        case 'surface'
            labels={'node_indices'};
            values={1:4000};

        otherwise
            error('Unsupported type ''%s''', data_type);
    end

    a.fdim.values=values;
    a.fdim.labels=labels;

function labels=get_meeg_channels(sens_type)

    % mapping from name to helper function
    % each name is prefixed with 'T' to allow names that start with a digit
    sens2func=struct();
    sens2func.Tneuromag306=@get_neuromag_chan;
    sens2func.Tctf151=@get_CTF151_chan;
    sens2func.T4d148=@get_4d148_chan;
    sens2func.T4d248=@get_4d248_chan;
    sens2func.Teeg1020=@get_eeg1020_chan;
    sens2func.Teeg1010=@get_eeg1010_chan;
    sens2func.Teeg1005=@get_eeg1005_chan;
    sens2func.Tyokogawa64=@get_yokogawa64_chan;
    sens2func.Tyokogawa160=@get_yokogawa160_chan;

    sp=cosmo_strsplit(['T' sens_type],'_');
    key=sp{1};
    if ~isfield(sens2func,key)
        supported_sens=fieldnames(sens2func);
        supported_labels=cellfun(@(x)[x(2:end) '*'],supported_sens,...
                        'UniformOutput',false);
        error('Unsupported sens_type %s, supported are: %s ',...
                    key(2:end),cosmo_strjoin(supported_labels, ', '));
    end

    func=sens2func.(key);
    chan_type=[cosmo_strjoin(sp(2:end),'_') '']; % ensure string
    labels=func(chan_type);


function labels=get_eeg1020_chan(chan_type)
    labels=get_eeg10XX_chan_helper(chan_type,'1020');

function labels=get_eeg1010_chan(chan_type)
    labels=get_eeg10XX_chan_helper(chan_type,'1010');

function labels=get_eeg1005_chan(chan_type)
    labels=get_eeg10XX_chan_helper(chan_type,'1005');


function labels=get_eeg10XX_chan_helper(chan_type,sens_type)
    assert(isempty(chan_type));

    % build mapping from prefix to postfixes
    ch=struct();
    switch sens_type
        case '1020'
            ch.Fp={ '1' '2' 'z' };
            ch.F={ '3' '4' '7' '8' 'z' };
            ch.T={ '3' '4' '5' '6' '7' '8' };
            ch.C={ '3' '4' 'z' };
            ch.P={ '3' '4' '7' '8' 'z' };
            ch.O={ '1' '2' 'z' };
            ch.A={ '1' '2' };
            ch.M={ '1' '2' };

        case '1010'
            ch.TP={ '10' '7' '8' '9' };
            ch.CP={ '1' '2' '3' '4' '5' '6' 'z' };
            ch.Fp={ '1' '2' 'z' };
            ch.AF={ '1' '10' '2' '3' '4' '5' '6' '7' '8' '9' 'z' };
            ch.F={ '1' '10' '2' '3' '4' '5' '6' '7' '8' '9' 'z' };
            ch.FT={ '10' '7' '8' '9' };
            ch.FC={ '1' '2' '3' '4' '5' '6' 'z' };
            ch.T={ '10' '3' '4' '5' '6' '7' '8' '9' };
            ch.C={ '1' '2' '3' '4' '5' '6' 'z' };
            ch.P={ '1' '10' '2' '3' '4' '5' '6' '7' '8' '9' 'z' };
            ch.PO={ '1' '10' '2' '3' '4' '5' '6' '7' '8' '9' 'z' };
            ch.O={ '1' '2' 'z' };
            ch.I={ '1' '2' 'z' };
            ch.A={ '1' '2' };
            ch.M={ '1' '2' };

        case '1005'
            ch.FCC={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h' '6'...
                    '6h' 'z' };
            ch.F={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h'...
                    '5' '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' ...
                    'p1' 'p1h' 'p2' 'p2h' 'pz' 'z' };
            ch.AF={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h'...
                    '5' '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' ...
                    'p1' 'p10' 'p10h' 'p1h' 'p2' 'p2h' 'p3' 'p3h' ...
                    'p4' 'p4h' 'p5' 'p5h' 'p6' 'p6h' 'p7' 'p7h' ...
                    'p8' 'p8h' 'p9' 'p9h' 'pz' 'z' };
            ch.FT={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.FC={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h'...
                    '6' '6h' 'z' };
            ch.T={ '10' '10h' '3' '4' '5' '6' '7' '7h' '8' '8h'...
                    '9' '9h' };
            ch.C={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h'...
                    '6' '6h' 'z' };
            ch.TP={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.CP={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h'...
                    '6' '6h' 'z' };
            ch.P={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h'...
                    '5' '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' 'z' };
            ch.PO={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h'...
                    '5' '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' 'z' };
            ch.O={ '1' '1h' '2' '2h' 'z' };
            ch.I={ '1' '1h' '2' '2h' 'z' };
            ch.AFF={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h'...
                    '5' '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' 'z' };
            ch.FFT={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.FFC={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h' '6'...
                    '6h' 'z' };
            ch.FTT={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.TTP={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.CCP={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h' '6'...
                    '6h' 'z' };
            ch.TPP={ '10' '10h' '7' '7h' '8' '8h' '9' '9h' };
            ch.CPP={ '1' '1h' '2' '2h' '3' '3h' '4' '4h' '5' '5h' '6'...
                    '6h' 'z' };
            ch.PPO={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h' '5'...
                    '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' 'z' };
            ch.POO={ '1' '10' '10h' '1h' '2' '2h' '3' '3h' '4' '4h' '5'...
                    '5h' '6' '6h' '7' '7h' '8' '8h' '9' '9h' 'z' };
            ch.OI={ '1' '1h' '2' '2h' 'z' };
            ch.A={ '1' '2' };
            ch.M={ '1' '2' };

        otherwise
            error('illegal senstype %s',sens_type);
    end

    prefixes=fieldnames(ch);
    nprefix=numel(prefixes);
    label_cell=cell(nprefix,1);
    for k=1:nprefix
        prefix=prefixes{k};
        postfixes=ch.(prefix);
        npostfix=numel(postfixes);
        prefix_labels=cell(npostfix,1);
        for j=1:npostfix
            postfix=postfixes{j};
            prefix_labels{j}=[prefix postfix];
        end
        label_cell{k}=prefix_labels;
    end
    labels=cat(1,label_cell{:});




function labels=get_4d248_chan(chan_type)
    labels=get_4dX48_chan_helper(chan_type,248);

function labels=get_4d148_chan(chan_type)
    labels=get_4dX48_chan_helper(chan_type,148);

function labels=get_yokogawa64_chan(chan_type)
    labels=get_yokogawaX_chan_helper(chan_type,64);

function labels=get_yokogawa160_chan(chan_type)
    labels=get_yokogawaX_chan_helper(chan_type,160);

function labels=get_yokogawaX_chan_helper(chan_type,nchan)
    labels=get_general_chan_helper(chan_type,nchan,...
                        'AG%03d','AG%03d_dH','AG%03d_dV');

function labels=get_4dX48_chan_helper(chan_type,nchan)
    labels=get_general_chan_helper(chan_type,nchan,...
                        'A%d','A%d_dH','A%d_dV');

function labels=get_general_chan_helper(chan_type,chan_vals,...
                        pat_combined, pat_planar1, pat_planar2)

    % if chan_vals is a scalar, it indicates the number of channels
    if isnumeric(chan_vals) && numel(chan_vals)==1
        % take the last channels
        chan_vals=num2cell(chan_vals:-1:1);
    end

    generate=@(pat) cellfun(@(x)sprintf(pat,x),chan_vals,...
                        'UniformOutput',false);
    switch chan_type
        case {'','planar_combined'}
            labels=generate(pat_combined)';
        case 'planar'
            labels=[generate(pat_planar1) generate(pat_planar2)]';
        otherwise
            error('illegal chan type %s', chan_type);
    end

function labels=get_CTF151_chan(chan_type)
    chan_vals=get_CTF151_chan_prefixes();
    labels=get_general_chan_helper(chan_type,chan_vals,...
                        '%s','%s_dH','%s_dV');

function labels=get_CTF151_chan_prefixes()
    % get channels for CTF151
    lats='LRZ';   % lateralities
    locs='CFOPT'; % brain part
    counts=[repmat({{[0,5,4,3,3],[0,2,3,4,5,2],[0,2,2,3,3],...
                            [0,3,2,4],[0,6,6,5,4]}},2,1);...
                    {{2,3,2,2}}];

    labels=cell(1,151);
    pos=0;
    for i=1:numel(lats)
        lat=lats(i);
        count=counts{i};
        for k=1:numel(count)
            loc=locs(k);
            cs=count{k};
            for j=1:numel(cs)
                for m=1:cs(j)
                    label=sprintf('M%s%s%d%d',lat,loc,j-1,m);
                    pos=pos+1;
                    labels{pos}=label;
                end
            end
        end
    end




function labels=get_neuromag_chan(chan_type)
    % get channels for neuromag system
    all_chan_idxs=[repmat((1:26)',4,1) kron((1:4)',ones(26,1))];
    remove_msk=cosmo_match(all_chan_idxs(:,1), 8) & ...
                        cosmo_match(all_chan_idxs(:,2),[3 4]);
    chan_idxs=all_chan_idxs(~remove_msk,:);
    nloc=size(chan_idxs,1);
    assert(nloc==102);

    infix=reshape(sprintf('%02d%d',chan_idxs'),3,[])';
    as_column=@(x) repmat(x,nloc,1);

    meg=as_column('MEG');
    one=as_column('1');
    two=as_column('2');
    three=as_column('3');
    plus_=as_column('+');

    labels=cell(nloc,4);
    labels(:,1)=cellstr([meg infix one]);
    labels(:,2)=cellstr([meg infix two]);
    labels(:,3)=cellstr([meg infix three]);
    labels(:,4)=cellstr([meg infix two plus_ infix three]);

    keep_col=false(1,4);
    types=cosmo_strsplit(chan_type,'+');
    for k=1:numel(types)
        tp=types{k};
        switch tp
            case {'all',''}
                keep_col([1 2 3])=true;
            case 'planar_combined'
                keep_col(4)=true;
            case 'planar'
                keep_col([2 3])=true;
            case 'axial'
                keep_col(1)=true;
            otherwise
                error('Unsupported channel type %s', tp);
        end
    end

    if any(keep_col(2:3)) && keep_col(4)
        error('planar and cmb/combined are mutually exclusive');
    end

    labels=labels(:,keep_col)';
    labels=labels(:);


function dim_size=get_dim_size(size_label)
    % get dimension size. NaN means use input size
    size2dim=struct();
    size2dim.tiny=[2 1 1];
    size2dim.small=[3 2 1];
    size2dim.normal=[3 2 5];
    size2dim.big=[NaN 7 5];
    size2dim.huge=[NaN 17 19];

    if ~isfield(size2dim, size_label)
        error('Unsupported size %s. Supported are: %s',...
                    size_label, cosmo_strjoin(fieldnames(size2dim),', '));
    end

    dim_size=size2dim.(size_label);


function [ds, nfeatures]=get_fdim_fa(opt)
    data_type=opt.type;
    size_label=opt.size;

    % get dimension labels
    a=dim_labels_values(opt);
    labels=a.fdim.labels;
    values=a.fdim.values;
    a=rmfield(a,'fdim');

    % get dimension values
    dim_sizes=get_dim_size(size_label);
    dim_sizes=dim_sizes(1:numel(labels));

    for k=1:numel(dim_sizes)
        if isnan(dim_sizes(k))
            dim_sizes(k)=numel(values{k});
        end
        values{k}=values{k}(1:dim_sizes(k));
    end

    % get ds with proper size
    ds=cosmo_flatten(zeros([1 dim_sizes]),labels,values);
    ds.a=cosmo_structjoin(ds.a,a);
    if strcmp(data_type,'fmri')
        ds.a.vol.dim=dim_sizes;
    end

    nfeatures=prod(dim_sizes);

