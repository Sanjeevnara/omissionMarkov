function om_decode_timegen_EN_SNDtoOM_MVPALight(subJ,chanType,Fs)
% training on sounds, testing on omissions, decoding entropy level

%%% obob
addpath('/mnt/obob/obob_ownft/');
cfg = [];
obob_init_ft (cfg);

%%% MVPALight
addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
%%% the rest
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding/functions/');

%% additional paths
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
fileDir= (['/mnt/obob/staff/gdemarchi/data/markov/raw/sss/']);
outDirTG_EN_SNDtoOM= (['/mnt/obob/staff/gdemarchi/data/markov/decoding/TG_EN_SNDtoOM/final/']);


%%%%%%%%%%%%%%%%%%%%%%%  COMMON PART  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
clear tmpdata data % to stay on the safe side
conds={'random*','midminus*','midplus*','ordered*'};
trialinfos = [];

%% loop on the 4 different entropy files ...
for iFile=1:length(conds)

  tmpFile= dir([fileDir,'*',subJ,'_block*',conds{iFile}]);
  cur_file = [tmpFile.folder,'/',tmpFile.name];

  % one long trial, for high pass filtering ...
  cfg = [];
  cfg.dataset = cur_file;
  cfg.trialdef.triallength = Inf;
  cfg.trialdef.ntrials = 1;
  cfg = ft_definetrial(cfg);

  cfg.channel = chanType;
  cfg.hpfreq = 0.1;
  cfg.hpinstabilityfix =  'split';
  tmpdata = ft_preprocessing(cfg);

  % get out the trials
  cfg = [];
  cfg.channel = chanType;
  cfg.dataset=cur_file ;
  cfg.trialdef.prestim =  1;
  cfg.trialdef.poststim = 1;
  cfg.trialdef.eventtype = 'Trigger';
  cfg.trialdef.eventvalue = [1 2 3 4 10 20 30 40]; % tones+omissions: OM needed later
  cfg_wtrials = ft_definetrial(cfg);
  data{iFile}= ft_redefinetrial(cfg_wtrials, tmpdata);
  clear tmpdata;

  data{iFile}.trialinfo(:,2)= iFile; %2n trialinfo column contains the entropy

  % lpfilter at 30, doesn't matter too much then, since we are downsampling anyway
  cfg=[];
  cfg.lpfilter = 'yes';
  cfg.lpfreq = 30;
  data{iFile} = ft_preprocessing(cfg,data{iFile});

  %%% fix the stimulus delay
  cfg = [];
  cfg.offset = -24; %24 samples at 1kHz
  data{iFile}        = ft_redefinetrial(cfg,data{iFile});

  % downsample always ....
  cfg=[];
  cfg.resamplefs=str2num(Fs);
  data{iFile}=ft_resampledata(cfg, data{iFile});
  trialinfos=[trialinfos; data{iFile}.trialinfo];

  if strcmp(chanType,'MEGGRAD') %combine the grads, if present
    cfg=[];
    data{iFile}=ft_combineplanar(cfg, data{iFile});
  else end
end

%% append all the files
cfg = [];
cfg.appenddim = 'rpt';
data=ft_appenddata(cfg, data{:});

%% a bit of useless cleaning, saves a lot of disk!
data = rmfield(data,'cfg');

%% ICA cleaning
if icaclean
  load('/mnt/obob/staff/gdemarchi/data/markov/ICAcomp/ICAcell.mat');
  load(['/mnt/obob/staff/gdemarchi/data/markov/ICAcomp/',subJ,'_ICAcomp.mat']);
  subjIdx = find(strcmp(subJ, ICAcell{1,1}));
  comps = ICAcell{2}{1,subjIdx};

  % remove the bad components and backproject the data
  cfg = [];
  cfg.component = comps; % to be removed component(s)
  data = ft_rejectcomponent(cfg, comp, data);
end
%%%%%%%%%%%%%%%%%%  END OF COMMON PART  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% time generalisation - train on sound test on omission

clear acc* result* cfg*
%% init MVPALight
startup_MVPA_Light;

%% get out sounds and omissions
cfg=[];
cfg.keeptrials='yes';
cfg.trials = find(data.trialinfo(:,1) < 9);
data_tl_SND=ft_timelockanalysis(cfg, data); % sounds
cfg.trials = find(data.trialinfo(:,1) > 9);
data_tl_OM=ft_timelockanalysis(cfg, data); % omissions


%% SNDtoOM entropy decoding
cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.balance = 'undersample';
% do the classifiction on the entropy level instead of sound
[accTG_SNDtoOM_EN, result_accTG_SNDtoOM_EN] = mv_classify_timextime(cfg, data_tl_SND.trial, data_tl_SND.trialinfo(:,2), data_tl_OM.trial, data_tl_OM.trialinfo(:,2));

%% weights come from the training on SND
% not needed here, I have them from the other decoding EN_SND and are the same
%stuffForWeights_trSND_EN = [];
%stuffForWeights_trSND_EN.cf        = result_accTG_SNDtoOM_EN.cf;
%stuffForWeights_trSND_EN.data = data_tl_SND.trial;
%stuffForWeights_trSND_EN.time      = data_tl_SND.time;
%stuffForWeights_trSND_EN.grad      = data_tl_SND.grad;
%stuffForWeights_trSND_EN.label     = data_tl_SND.label;
%stuffForWeights_trSND_EN.trialinfo = data_tl_SND.trialinfo(:,1);

% get the time, save time as well
time=data_tl_SND.time;

%% and save!
outFile = [ subJ '_'  chanType '_timegen_EN_SNDtoOM_Fs' Fs  '.mat'];
save (fullfile(outDirTG_EN_SNDtoOM, outFile),'acc*','result*','time' ,'-v7.3'); 
