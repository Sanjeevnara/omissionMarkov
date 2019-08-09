function [dataOut, minTrl] = balanceForDecoding(dataIn, removeSelfRepetitions)
%% I've to balance the sequence 11 12 24 44 etc etc ..
% 20180802: added the capability to reject the trials that had previously
%           an omission

seqCurr = dataIn.trialinfo(:,1);
seqPrevious = [seqCurr(end) ; seqCurr(1:end-1)];

%make a list of previous and current trials, and balance it
foo=str2num([num2str(seqPrevious');num2str(seqCurr')]');

for iPrev=1:4 % 4x4 original index matrix
    for iCurr=1:4
        trlCond = str2num([num2str(iPrev) ; num2str(iCurr)]');
        oldIdx{iPrev,iCurr} = find(foo==trlCond);
    end
end

% check the minimun number of trials and randomly select these trials from
% the original chunks ...
minTrl = min(min(cellfun('length',oldIdx)));
for iPrev=1:4
    for iCurr=1:4
        tmpIdx = randperm(length(oldIdx{iPrev,iCurr}),minTrl); %HINT: randperm(population,sample);
        newIdx{iPrev,iCurr}= oldIdx{iPrev,iCurr}(tmpIdx);

        if removeSelfRepetitions==1 && iPrev==iCurr% i.e. on the diagonal
          newIdx{iPrev,iCurr} = []; % remove forcibly the self repetitions
        end

    end
end

% convert the matrix of indices to linear indices
finalIdx = cell2mat(newIdx(:));

% select and ouput the data
cfg = [];
cfg.trials = [finalIdx];
dataOut = ft_selectdata(cfg,dataIn);

if minTrl < 100
  dataOut.warning = 'WTF!!! This one had less than 100 minimum trials!';
  dataOut.mintrls =  minTrl;
end
