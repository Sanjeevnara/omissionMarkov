function [dataOut] = removeTrlsIfPreviousOmission(dataIn)
% as the name implies
seqCurr = dataIn.trialinfo(:,1);
seqPrevious = [seqCurr(end) ; seqCurr(1:end-1)];

newSeq = zeros(length(seqCurr),1);
for iSeq = 1:length(seqCurr)
  if seqCurr(iSeq)> 9  % I remove obviosly the omissions
    newSeq(iSeq) = 0;
  elseif iSeq>1 && (seqCurr(iSeq-1) > 9) %remove, since preceded by OM
    newSeq(iSeq) = 0;
  else % default, just copy the data
    newSeq(iSeq) = seqCurr(iSeq);
  end
end

% ft_selectdata and ouput the data
cfg = [];
cfg.trials = [find(newSeq)];
dataOut = ft_selectdata(cfg,dataIn);
