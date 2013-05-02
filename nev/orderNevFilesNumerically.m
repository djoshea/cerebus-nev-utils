function fnames = orderNevFilesNumerically(nevNames)
% returns nevNames ordered by numerical suffix,
% specifically sort by monkeyInitial ascending, dateString ascending, number ascending, protocol ascending

[info sortInds] = sortStructArray(parseNevName(nevNames), {'monkeyInitial', 'dateString', 'number', 'protocol'});

fnames = nevNames(sortInds);

end
