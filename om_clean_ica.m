function om_clean_ica(subJ)
% ica cleaning instead of removing a shitload of trials

%%% obob
addpath('/mnt/obob/obob_ownft/');
cfg = [];
obob_init_ft (cfg);

%%% the rest
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding');
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding/functions/');


%%% reading the data part
fileDir= (['/mnt/obob/staff/gdemarchi/data/markov/raw/sss/']);
outDirICA= (['/mnt/obob/staff/gdemarchi/data/markov/ICAcomp/']);

%% main loop over the files
clear tmpdata data % to stay on the safe side
conds={'random*','midminus*','midplus*','ordered*'};

for iFile=1:length(conds)

  tmpFile= dir([fileDir,'*',subJ,'_block*',conds{iFile}]);
  cur_file = [tmpFile.folder,'/',tmpFile.name];

  % continuous data for hp filtering
  cfg = [];
  cfg.dataset = cur_file;
  cfg.trialdef.triallength = Inf;
  cfg.trialdef.ntrials = 1;
  cfg = ft_definetrial(cfg);

  cfg.channel = {'MEG'};
  cfg.hpfilter = 'yes';
  cfg.hpfreq = 1; % for ICA components 1 Hz is good enough
  cfg.hpinstabilityfix =  'split';
  tmpdata = ft_preprocessing(cfg);

  cfg = [];
  cfg.channel = {'MEG'}; %do all the MEG together, pre whitening should take care of different scales
  cfg.dataset=cur_file ;
  cfg.trialdef.triallength = 10; % 10s chunks, to have a better overview of the compents
  cfg.trialdef.ntrials = Inf;
  cfg = ft_definetrial(cfg);
  tmpdata = ft_redefinetrial(cfg, tmpdata);

  % downsampling to 256Hz, more than enough for ICA since we have a lot of data
  cfg=[];
  cfg.resamplefs=256; % change on cluster
  data{iFile} = ft_resampledata(cfg, tmpdata);

end

clear tmpdata;

%% appending the blocks
cfg = [];
cfg.appenddim = 'rpt';
data=ft_appenddata(cfg, data{:});


%% a bit of useless crap cleaning, saves a lot of disk!
data = rmfield(data,'cfg');


%% Do the ICA computing
cfg        = [];
cfg.method = 'runica';
cfg.runica.pca = 50 ; % since maxfiltered
comp = ft_componentanalysis(cfg, data);

%% and save!
outFile = [ subJ '_ICAcomp.mat'];
save (fullfile(outDirICA, outFile),'comp','-v7.3');
