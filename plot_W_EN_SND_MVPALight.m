%% plot weights of entropy decoding
clear all; close all;

%% set ft path and init
if ismac
    myftpath = '/Users/gianpaolo/git/fieldtrip' ;s
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
    fileDir = (['/Users/gianpaolo/Nextcloud/Documents/Manuscripts/omissionMarkov/figures/wEN/final/']);
else
    addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
    startup_MVPA_Light;
    addpath /mnt/obob/staff/gdemarchi/mattools/;
    addpath /mnt/obob/staff/gdemarchi/git/export_fig/;
    addpath /mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding/functions/
    fileDir = (['/mnt/obob/staff/gdemarchi/data/markov/decoding/beamweightsEN/final/']);
end

%% list of subjects
subjList =  {'PNRK','KRHR','GBSH', 'BRHC','CRLE', 'ANSR','SSLD','AGSG','RFTM','SLBR','GDZN','EEHB', 'BTKC', 'GNTA','SZDT','SBPE','KTAD','IMSH','ATLI','HLHY','IGSH','MCSH','CRBC','GBHL','MNSU','IIQI','HIEC','KRKE', 'BRSH','LLZM','EIFI','MRGU','IONP'};

%% load the weights-projected-onto-source virtual sensons
clear data_* tmpsrc source*

fNamePart = '*weights_beamed_15pcRegFac_yesICA_GaetanStyle.mat';
for iFile=1:length(subjList)
  if ~isempty(dir([fileDir subjList{iFile} fNamePart ]))
    fileToRead  = dir([fileDir subjList{iFile} fNamePart]);
  else
    fprintf('\n File %s missing ... something went wrong?!', subjList{iFile})
    continue
  end

  curFile = fileToRead.name;
  tmpsrc=load([fileDir curFile]);
  tmpsrc.data_source.avg = abs(tmpsrc.data_source.avg); % check whether it was alread done before ...
  data_source_avg{iFile} = tmpsrc.data_source;
  fprintf('Subject %s done! (%d %%) \n\n', subjList{iFile}, round(100*(iFile/length(subjList))))
end

%%  single subject baselinie correction
for iFile=1:length(data_source_avg)
  cfg=[];
  cfg.baseline=  [-.05 0]; %
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
cfg=[];
cfg.sourcegrid =  template_grid;
cfg.parameter={'avg'};
cfg.toilim=[.05 300];% the whole peak ...
cfg.mri = mri;
source2plot = obob_svs_virtualsens2source(cfg, GA_source_avg_rel);%

% to stay on the safe side
source2plot.coordsys = 'mni';

%% finally source plots
% ortho
cfg = [];
cfg.funparameter = 'avg';
cfg.maskparameter =cfg.funparameter;%
cfg.crosshair = 'yes';%'no';
cfg.funcolormap = 'jet';
ft_sourceplot(cfg, source2plot);


%% surface plot
cfg = [];
cfg.method         = 'surface';
cfg.funparameter   = 'avg';
cfg.funcolormap    = 'jet';
cfg.projmethod     = 'nearest';
cfg.camlight       = 'no';
cfg.colorbar = 'yes';
cfg.maskparameter= cfg.funparameter;% 'mask';
cfg.funcolorlim   = [-1 1]; %keep it consistent
cfg.surfinflated   = 'surface_inflated_both_caret.mat';
ft_sourceplot(cfg, source2plot);

view([90, 0])
material dull
camlight
% saveas(gcf,[fileDir 'EntropyRight_th50.tif']);
% view([-90, 0])
% delete(findall(gcf,'Type','light')); % remove the old lights
% camlight
% saveas(gcf,[fileDir 'EntropyLeft_th50.tif']);
% camlight headlight
