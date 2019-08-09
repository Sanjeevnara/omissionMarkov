function om_decode_timegen_trSNDteOM_MVPALight(subJ,chanType,balanceYN,selfRepetitions, Fs, icaClean)
% train on RD sound and test on *all* omissions

%%% obob
addpath('/mnt/obob/obob_ownft/');
cfg = [];
obob_init_ft (cfg);

%%% MVPALight
addpath(genpath('/mnt/obob/staff/gdemarchi/git/MVPA-Light/'));
%%% the rest
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding/functions/');

startup_MVPA_Light;

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
outDirTG= (['/mnt/obob/staff/gdemarchi/data/markov/decoding/TG_trSNDteOM_prestim/final/']);

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

%% decoding part, train on random sounds post stimulus, test on omissions pre and post
clear tmpdata* accTG* result_accTG*

cfg=[];
cfg.latency = [0 1];
tmpdataPost=ft_selectdata(cfg, data);
cfg.latency = [-1 0];
tmpdataPre=ft_selectdata(cfg, data);


%% train sounds plus omissions test sounds

% all the idxs ...
sndIdxRD = intersect(find(tmpdataPre.trialinfo(:,2)==1),find(tmpdataPre.trialinfo(:,1)<9)); %rand  sounds
omIdxRD  = intersect(find(tmpdataPre.trialinfo(:,2)==1),find(tmpdataPre.trialinfo(:,1)>9)); %rand  omissions

sndIdxMM = intersect(find(tmpdataPre.trialinfo(:,2)==2),find(tmpdataPre.trialinfo(:,1)<9)); %mm sounds
omIdxMM  = intersect(find(tmpdataPre.trialinfo(:,2)==2),find(tmpdataPre.trialinfo(:,1)>9)); %mm omissions

sndIdxMP = intersect(find(tmpdataPre.trialinfo(:,2)==3),find(tmpdataPre.trialinfo(:,1)<9)); %mp sounds
omIdxMP  = intersect(find(tmpdataPre.trialinfo(:,2)==3),find(tmpdataPre.trialinfo(:,1)>9)); %mp omissions

sndIdxOR = intersect(find(tmpdataPre.trialinfo(:,2)==4),find(tmpdataPre.trialinfo(:,1)<9)); %ordered sounds
omIdxOR  = intersect(find(tmpdataPre.trialinfo(:,2)==4),find(tmpdataPre.trialinfo(:,1)>9)); %ordered omissions

allIdxRD = find(data.trialinfo(:,2)==1); %random sounds and omissions


cfg=[];
cfg.keeptrials='yes';
cfg.trials = [allIdxRD ]; % I need sounds plus omissions for the next funciton!
trainRdSNDpost=ft_timelockanalysis(cfg, data) %tmpdataPost); %random sounds

% get out the sounds *not* preceded by omissions, and remove the omisisions
% as well ...
trainRdSNDpost = removeTrlsIfPreviousOmission(trainRdSNDpost);
% now balance the conditions without removin the self repetitions
trainRdSNDpost=balanceForDecoding(trainRdSNDpost, sRep);


%% training on post stimulus RdSND and testing on *all* the pre and post stimulus RD omission
cfg=[];
cfg.keeptrials='yes';
cfg.trials = [omIdxRD];
testRD=ft_timelockanalysis(cfg, data);  %
% fix labels for MVPALight, likes 1 2 3 4 etc
testRD.trialinfo(testRD.trialinfo(:,1)>4) = testRD.trialinfo(testRD.trialinfo(:,1)>4)/10;

cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.time1 = [floor((length(data.time{1})/2)+1):length(data.time{1})];
cfg.time2 = [1:length(data.time{1})]; %pre stim testing time
[accTG_RdSNDPostStim_RdOM, result_accTG_RdSNDPostStim_RdOM] = mv_classify_timextime(cfg, trainRdSNDpost.trial, trainRdSNDpost.trialinfo(:,1),testRD.trial, testRD.trialinfo(:,1));

%% training on post stimulus RdSND and testing on *all* the pre and post stimulus MM omission
cfg=[];
cfg.keeptrials='yes';
cfg.trials = [omIdxMM];%[sndIdxMM ; omIdxMM]; %
testMM=ft_timelockanalysis(cfg, data);  %
% fix labels for MVPALight, likes 1 2 3 4 etc
testMM.trialinfo(testMM.trialinfo(:,1)>4) = testMM.trialinfo(testMM.trialinfo(:,1)>4)/10;

cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.time1 = [floor((length(data.time{1})/2)+1):length(data.time{1})];
cfg.time2 = [1:length(data.time{1})]; %pre stim testing time
[accTG_RdSNDPostStim_MmOM, result_accTG_RdSNDPostStim_MmOM] = mv_classify_timextime(cfg, trainRdSNDpost.trial, trainRdSNDpost.trialinfo(:,1),testMM.trial, testMM.trialinfo(:,1));

%% training on post stimulus RdSND and testing on *all* the pre and post stimulus MP omission
cfg=[];
cfg.keeptrials='yes';
cfg.trials = [omIdxMP];
testMP=ft_timelockanalysis(cfg, data);  %
% fix labels for MVPALight, likes 1 2 3 4 etc
testMP.trialinfo(testMP.trialinfo(:,1)>4) = testMP.trialinfo(testMP.trialinfo(:,1)>4)/10;

cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.time1 = [floor((length(data.time{1})/2)+1):length(data.time{1})]; %post stim training time
cfg.time2 = [1:length(data.time{1})]; %pre stim testing time
[accTG_RdSNDPostStim_MpOM, result_accTG_RdSNDPostStim_MpOM] = mv_classify_timextime(cfg, trainRdSNDpost.trial, trainRdSNDpost.trialinfo(:,1),testMP.trial, testMP.trialinfo(:,1));

%% training on post stimulus RdSND and testing on *all* the pre and post stimulus OR omission
cfg=[];
cfg.keeptrials='yes';
cfg.trials = [omIdxOR];
testOR=ft_timelockanalysis(cfg, data);
% fix labels for MVPALight, likes 1 2 3 4 etc
testOR.trialinfo(testOR.trialinfo(:,1)>4) = testOR.trialinfo(testOR.trialinfo(:,1)>4)/10;

cfg =  [];
cfg.classifier = 'multiclass_lda';
cfg.metric     = 'acc';
cfg.time1 = [floor((length(data.time{1})/2)+1):length(data.time{1})]; %post stim training time
cfg.time2 = [1:length(data.time{1})]; %pre stim testing time
[accTG_RdSNDPostStim_OrOM, result_accTG_RdSNDPostStim_OrOM] = mv_classify_timextime(cfg, trainRdSNDpost.trial, trainRdSNDpost.trialinfo(:,1),testOR.trial, testOR.trialinfo(:,1));

% get the time axes
timeTrain=trainRdSNDpost.time(floor((length(data.time{1})/2)+1):length(data.time{1})); %in fact i am trainiing only on the second half
timeTest=data.time{1};

%% weights come from the training on RdSND
stuffForWeights_trRdSNDpost           = [];
stuffForWeights_trRdSNDpost.cf        = result_accTG_RdSNDPostStim_RdOM.cf;
stuffForWeights_trRdSNDpost.data      = trainRdSNDpost.trial;
stuffForWeights_trRdSNDpost.time      = trainRdSNDpost.time;
stuffForWeights_trRdSNDpost.grad      = trainRdSNDpost.grad;
stuffForWeights_trRdSNDpost.label     = trainRdSNDpost.label;
stuffForWeights_trRdSNDpost.trialinfo = trainRdSNDpost.trialinfo(:,1);

%% and save!
outFile = [ subJ '_'  chanType '_timegen_trRdSNDteALLOM_plusW_'  icaString '_' balanceString '_' sRepString  '_Fs' Fs '_reallyFinal.mat'];
save (fullfile(outDirTG, outFile),'accTG*','result_accTG*','time*', 'stuff*','-v7.3');
