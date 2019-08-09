function om_beam_weights(subJ)

%%% obob
addpath('/mnt/obob/staff/gdemarchi/git/obob_ownft/');
cfg = [];
cfg.package.svs = 'true';
cfg.package.obsolete = 'true';
obob_init_ft(cfg);

%%% MVPALight
addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
startup_MVPA_Light;

%%% useful stuff
addpath /mnt/obob/staff/gdemarchi/mattools/;
addpath /mnt/obob/staff/gdemarchi/git/export_fig/;

%%% various paths ...
fileDir = (['/mnt/obob/staff/gdemarchi/data/markov/decoding/TG_trSNDteOM_prestim/final/']);
outDir  = (['/mnt/obob/staff/gdemarchi/data/markov/decoding/beamweights/final/']);
rawDir= (['/mnt/obob/staff/gdemarchi/data/markov/raw/sss/']);

%%
close all;
clear tmpdata data % to stay on the safe side
conds={'random*','midminus*','midplus*','ordered*'};
trialinfos = [];

%%% read the TG data, containing the weights
fileToRead  = dir([fileDir subJ '*_plusW_ICAcleaned_balanced_woSelfRepetitions_lda_Fs100_reallyFinal*']);

curFile = fileToRead.name;
tmptg=load([fileDir curFile]);
TG_res  = tmptg.result_accTG_RdSNDPostStim_RdOM;
stuffForWeigths = tmptg.stuffForWeights_trRdSNDpost;
trainTime= tmptg.timeTrain;


%%% for each time point, do the Haufe balancing
for iTime =1:length(tmptg.timeTrain)
  tmppattern = mv_stat_activation_pattern(stuffForWeigths.cf{iTime}, stuffForWeigths.data(:,:,iTime), stuffForWeigths.trialinfo(:,1));
  weigths(:,iTime) =tmppattern(:,1); %take the strongest SVD ...
  fprintf('timepoint: %d done!\n', iTime);
end

%%% create the fake topography
clear tmpW
tmpW = [];
tmpW.avg = squeeze(weigths);
tmpW.time = trainTime;
tmpW.grad= stuffForWeigths.grad;
tmpW.label= stuffForWeigths.label;
tmpW.dimord = 'chan_time';

%%% quick source analysis
%% steal head stuff from gaetan

headFile = ['/mnt/obob/staff/gsanchez/markov_gd/mri/*',subJ,'/*', subJ '*_hdm_trans.mat'];
fName = dir(headFile);
load([fName.folder '/' fName.name]);
hdm = vol; % old naming style
individual_grid = grid_warped;
% end stealing from gaetan

% convert all to 'm', to stay on the safe side ...
stuffForWeigths.grad = ft_convert_units(stuffForWeigths.grad,'m');
hdm  = ft_convert_units(hdm,'m');
individual_grid =  ft_convert_units(individual_grid,'m');

% compute the leadfield
cfg=[];
cfg.channel = {'MEGMAG'};
cfg.vol=hdm;
cfg.grid=individual_grid;
cfg.grid.unit = 'm';
cfg.grad=stuffForWeigths.grad;
cfg.normalize='yes';
lf=ft_prepare_leadfield(cfg);

% create one time axis per trial, as fieldtrip likes ...
nTrl = max(size(stuffForWeigths.data));
timeTrl = stuffForWeigths.time;

stuffForWeigths = rmfield(stuffForWeigths,'time');

for iTrl = 1:nTrl
  stuffForWeigths.trial{iTrl}   = squeeze(stuffForWeigths.data(iTrl,:,:));
  stuffForWeigths.time{iTrl}    = timeTrl;
end
stuffForWeigths.dimord = 'rpt_chan_time'; %maybe not neede in future
stuffForWeigths = rmfield(stuffForWeigths,'data');

%% compute the covariance matrix
cfg=[];
cfg.channel = {'MEGMAG'};
cfg.preproc.hpfilter   = 'yes';
cfg.preproc.hpfreq     = 1;
cfg.preproc.lpfilter   = 'yes';
cfg.preproc.lpfreq     = 45;
cfg.covariance         = 'yes';
data_avg = ft_timelockanalysis(cfg, stuffForWeigths);

%% compute spatial filters
cfg=[];
cfg.method          = 'lcmv';
cfg.vol.unit        = 'm'; %
cfg.grid            = lf;
%cfg.projectnoise    = 'yes';
cfg.lcmv.keepfilter = 'yes';
cfg.lcmv.fixedori   = 'yes';
cfg.lcmv.lambda     = '15%'; % according to Litvak at least 15% for SSS-ed data
%cfg.lcmv.powmethod = 'yes';
lcmvall=ft_sourceanalysis(cfg, data_avg);

%% build the virtual sensors as normal
beamfilts = cat(1,lcmvall.avg.filter{:});

data_source = stuffForWeigths;
data_source=rmfield(data_source,'trial');

%%% now I project the weights, i.e. the topography onto the brain
data_source.avg = beamfilts*tmpW.avg;
% abs needed (?)
% data_source.pow = abs(beamfilts*tmpW.avg); %check abs here!!!

% fake labels
data_source.label = cellstr(num2str([1:sum(lf.inside)]'));
data_source.dimord = 'chan_time';
data_source.time = tmpW.time;


%% here I  save ...
outFile = [ subJ '_weights_beamed_15pcRegFac_yesICA_GaetanStyle.mat'];
save (fullfile(outDir, outFile),'data_source*','tmpW*','-v7.3');
