function isSortedNev = checkNevInSortedDirectory(nevFile)
% returns true iff nevFile is in the sorted directory within a data directory
% this sorted directory name is part of the data context

% check whether the trailing folder name matches the sortedNevDirectory for the context
[path name ext] = fileparts(nevFile);
[~, context] = getDataContextForDirectory(path);

if isempty(context)
    isSortedNev = false;
else
    [~, trailingDirectory] = fileparts(path);
    isSortedNev = strcmp(trailingDirectory, context.sortedNevDirectory);
end
