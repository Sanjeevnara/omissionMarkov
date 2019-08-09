%% run om_beam_weightsEN
clear all
close all

addpath('/mnt/obob/obob_ownft/');

%% obob
cd /mnt/obob/staff/gdemarchi/DataAnalysis
cfg = [];
cfg.package.hnc_condor = true;
obob_init_ft(cfg);

cfg = [];
cfg.adjust_mem = true;
cfg.mem = '33G';
cfg.jobsdir      = '/mnt/obob/staff/gdemarchi/jobs/';
condor_struct = obob_condor_create(cfg);

% paths
addpath ('/mnt/obob/staff/gdemarchi/DataAnalysis/omissionMarkov/decoding')

subjList =  {'PNRK','KRHR','GBSH', 'BRHC','CRLE', 'ANSR','SSLD','AGSG','RFTM','SLBR','GDZN','EEHB', 'BTKC', 'GNTA','SZDT','SBPE','KTAD','IMSH','ATLI','HLHY','IGSH','MCSH','CRBC','GBHL','MNSU','IIQI','HIEC','KRKE', 'BRSH','LLZM','EIFI','MRGU','IONP'};

condor_struct = obob_condor_addjob_cell(condor_struct, 'om_beam_weightsEN', subjList);
%fire!
obob_condor_submit(condor_struct)
