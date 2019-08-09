%%% plot weights of the decoder trained on RdSND
clear all; close all;

%% set ft path and init
if ismac
    myftpath = '/Users/gianpaolo/git/fieldtrip' ;
    addpath ~/git/obob_ownft/
else
    myftpath = [];
    addpath('/mnt/obob/staff/gdemarchi/git/obob_ownft/');
end

cfg = [];
cfg.package.svs = 'true';
cfg.package.obsolete = 'true';
cfg.ft_path = myftpath;
obob_init_ft(cfg);

%% add afterwards MVPALight
if ismac
    addpath(genpath('~/git/myMVPA-Light/'));
    startup_MVPA_Light;
    fileDir = (['/Users/gianpaolo/Nextcloud/Documents/Manuscripts/omissionMarkov/figures/wRdSND/final/']);
else
    addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
    startup_MVPA_Light;
    addpath /mnt/obob/staff/gdemarchi/mattools/;
    addpath /mnt/obob/staff/gdemarchi/git/export_fig/;
    fileDir = (['/mnt/obob/staff/gdemarchi/data/markov/decoding/beamweights/final/']);
end

%% list of subjects
subjList =  {'PNRK','KRHR','GBSH', 'BRHC','CRLE', 'ANSR','SSLD','AGSG','RFTM','SLBR','GDZN','EEHB', 'BTKC', 'GNTA','SZDT','SBPE','KTAD','IMSH','ATLI','HLHY','IGSH','MCSH','CRBC','GBHL','MNSU','IIQI','HIEC','KRKE', 'BRSH','LLZM','EIFI','MRGU','IONP'};

%% load the weights-projected-onto-source virtual sensons
clear data_* tmpsrc source*

fNamePart = '*weights_beamed_15pcRegFac_yesICA_GaetanStyle.mat';
for iFile=1:length(subjList)
  if ~isempty(dir([fileDir subjList{iFile} fNamePart ]));
    fileToRead  = dir([fileDir subjList{iFile} fNamePart]);
  else
    fprintf('\n File %s missing ... something went wrong?!', subjList{iFile})
    continue
  end

  curFile = fileToRead.name;
  tmpsrc=load([fileDir curFile]);
  data_source_avg{iFile} = tmpsrc.data_source;
  fprintf('Subject %s done! (%d %%) \n\n', subjList{iFile}, round(100*(iFile/length(subjList))))
end

%% single subject baseline correction
for iFile=1:length(data_source_avg)
  cfg=[];
  cfg.baseline=  [-0.05 0];  %
  cfg.baselinetype='relchange';
  data_sourcebl_rel{iFile}=obob_svs_timelockbaseline(cfg,  data_source_avg{iFile});
  fprintf('Subject %s done! (%d %%) \n\n', subjList{iFile}, round(100*(iFile/length(subjList))))
end

GA_source_avg_rel = ft_timelockgrandaverage([],data_sourcebl_rel{:});

%% source plotting part
load mni_grid_1_5_cm_889pnts.mat
load standard_mri_better.mat
load standard_mri_better_segmented.mat

%% virtual sensors to source structure ...
% early component a.k.a. W1
cfg=[];
cfg.sourcegrid =  template_grid;
cfg.parameter={'avg'};
cfg.toilim=[.05 .125];
cfg.mri = mri; % mri/mri_better depends ...
source2plotE = obob_svs_virtualsens2source(cfg, GA_source_avg_rel);

%late componenta.k.a. W2
cfg.toilim=[.125 .33];
source2plotL = obob_svs_virtualsens2source(cfg, GA_source_avg_rel);

%% finally source plots
% ortho
cfg = [];
cfg.funparameter = 'avg';
cfg.maskparameter =cfg.funparameter;
cfg.funcolormap = 'jet';
ft_sourceplot(cfg, source2plotL);

%% surface plot(s)
cfg = [];
cfg.method         = 'surface';
cfg.funparameter   = 'avg';
cfg.funcolormap    = 'jet';
cfg.projmethod     = 'nearest';
cfg.projthresh     = 0.5;
cfg.camlight       = 'no';
cfg.colorbar = 'yes';
cfg.maskparameter= cfg.funparameter;%
cfg.surfinflated   = 'surface_inflated_both_caret.mat';
cfg.funcolorlim   = [-3 3]; %keep it consistent

% early component
ft_sourceplot(cfg, source2plotE);
view([90, 0])
material dull
camlight
% save left/right views sepatare
% saveas(gcf,[fileDir 'EarlyRight_th50.tif']);
% view([-90, 0])
% delete(findall(gcf,'Type','light')); % remove the old lights
% camlight
% saveas(gcf,[fileDir 'EarlyLeft_th50.tif']);

% late component
ft_sourceplot(cfg, source2plotL);
view([90, 0])
material dull
camlight
% save left/right views sepatare
% saveas(gcf,[fileDir 'LateRight_th50.tif']);
% view([-90, 0])
% delete(findall(gcf,'Type','light')); % remove the old lights
% camlight
% saveas(gcf,[fileDir 'LateLeft_th50.tif']);
