function om_decode_timegen_trSNDteSND_MVPALight(subJ,chanType,balanceYN, selfRepetitions, Fs, icaClean)
% training on random sound, testing on sounds, all entropies

%%% obob/ft
addpath('/mnt/obob/obob_ownft/');
cfg = [];
obob_init_ft (cfg);

%%% MVPALight
addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
%%% the rest
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding/functions/');

%%% too many input options, think of moving to cfg. scheme
%%% check defaults
if strcmp(balanceYN,'no')
  balanceCond =0;
  balanceString = 'unbalanced';
else %default, balance
  balanceCond =1;
  balanceString = 'balanced'; %default
end

if strcmp(selfRepetitions,'no')
  sRep =1; % remove the self repetitions
  sRepString = 'woSelfRepetitions';
else
  sRep =0; % keep the self repetitions
  sRepString = 'wSelfRepetitions';
end

if strcmp(icaClean,'yes')
  icaclean =1;
  icaString = 'ICAcleaned';
else
  icaclean =0;
  icaString = 'UNCLEANED';
end

%% additional paths
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
fileDir= (['/mnt/obob/staff/gdemarchi/data/markov/raw/sss/']);
outDirTGSND= (['/mnt/obob/staff/gdemarchi/data/markov/decoding/TG_trSNDteSND/final/']);

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

%% decoding part, train on random sounds, test on all the rest
clear acc* result* cfg*
startup_MVPA_Light; %init mvpa light

allIdxRD = find(data.trialinfo(:,2)==1); %random sounds and omissions idxs

cfg=[];
cfg.keeptrials='yes';
cfg.trials = [allIdxRD ]; %
data_tl_rdALL=ft_timelockanalysis(cfg, data); %random sounds and omissions

% get out the sounds *not* preceded by omissions
data_tl_snd_rd = removeTrlsIfPreviousOmission(data_tl_rdALL);
%final fine-tuned balancing before sending to the decoder ...
[data_tl_snd_rd,dimTraining] =balanceForDecoding(data_tl_snd_rd, sRep); %leave the self rep in 0, 1 remove them

%% TG RdSNDtoSND
cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.balance = 'undersample';
[accTG_SND_RD, result_accTG_SND_RD] = mv_classify_timextime(cfg, data_tl_snd_rd.trial, data_tl_snd_rd.trialinfo(:,1));

%% select MM, MP, OR data
sndIdxMM = intersect(find(data.trialinfo(:,2)==2),find(data.trialinfo(:,1)<9)); %mm sounds
cfg=[];
cfg.keeptrials='yes';
cfg.trials = sndIdxMM; %
data_tl_snd_mm=ft_timelockanalysis(cfg, data);

sndIdxMP = intersect(find(data.trialinfo(:,2)==3),find(data.trialinfo(:,1)<9)); %mp sounds
cfg=[];
cfg.keeptrials='yes';
cfg.trials = sndIdxMP; %
data_tl_snd_mp=ft_timelockanalysis(cfg, data);

sndIdxOR = intersect(find(data.trialinfo(:,2)==4),find(data.trialinfo(:,1)<9)); %or sounds
cfg=[];
cfg.keeptrials='yes';
cfg.trials = sndIdxOR; %
data_tl_snd_or=ft_timelockanalysis(cfg, data);

%% TG Rd_SND to Mm_SND
cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.balance = 'undersample';
[accTG_SND_RD_MM, result_accTG_SND_RD_MM] = mv_classify_timextime(cfg, data_tl_snd_rd.trial, data_tl_snd_rd.trialinfo(:,1),data_tl_snd_mm.trial, data_tl_snd_mm.trialinfo(:,1));

% TG Rd_SND to Mp_SND
cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.balance = 'undersample';
[accTG_SND_RD_MP, result_accTG_SND_RD_MP] = mv_classify_timextime(cfg,data_tl_snd_rd.trial, data_tl_snd_rd.trialinfo(:,1),data_tl_snd_mp.trial, data_tl_snd_mp.trialinfo(:,1));

% TG  Rd_SND to Or_SND
cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.balance = 'undersample';
[accTG_SND_RD_OR, result_accTG_SND_RD_OR] = mv_classify_timextime(cfg,data_tl_snd_rd.trial, data_tl_snd_rd.trialinfo(:,1),data_tl_snd_or.trial, data_tl_snd_or.trialinfo(:,1));


% get the time axis, save time as well
time=data_tl_snd_rd.time;

%% build the weights structure
stuffForWeights_trRdSND = [];
stuffForWeights_trRdSND.cf        = result_accTG_SND_RD.cf;
stuffForWeights_trRdSND.data      = data_tl_snd_rd.trial;
stuffForWeights_trRdSND.time      = data_tl_snd_rd.time;
stuffForWeights_trRdSND.grad      = data_tl_snd_rd.grad;
stuffForWeights_trRdSND.label     = data_tl_snd_rd.label;
stuffForWeights_trRdSND.trialinfo = data_tl_snd_rd.trialinfo(:,1);

%% and save!
outFile = [ subJ '_'  chanType '_timegen_trOnRdSND_teSND_plusW_' icaString '_' balanceString '_' sRepString  '_Fs' Fs '_reallyFinal_balancedForDecoding.mat'];
save (fullfile(outDirTGSND, outFile),'acc*','result*','time', 'stuff*','-v7.3');
