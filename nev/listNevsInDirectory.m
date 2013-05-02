function fileList = listNevsInDirectory(directory, varargin)
% fileList = listNevsInDirectory(directory, varargin)
% 
% Returns a list of fully-qualified nev file names in directory, ordered according to their numerical suffix
% If a nev of equivalent name exists within sortedNevDirectory (inside the dataContext), 
%   the path to this sorted nev file

% replace a nev file with its sorted equivalent located in the sortedNevDirectory (located in the context)
def.checkSortedNevs = true;
assignargs(def, varargin);

if ~exist('directory', 'var')
	directory = '';
end
directory = checkOrPromptDataDirectory(directory);

% order the nevs according to their numerical suffix before loading
fileList = orderNevFilesNumerically(listFilesInDirectory(directory, 'nev'));

% check for presence of sorted nev file in subdirectory
[contextKey context] = getDataContextForDirectory(directory);
sortedNevDirectory = fullfile(directory, context.sortedNevDirectory);
for iFile = 1:length(fileList)
	[~, fileName, fileExt] = fileparts(fileList{iFile});
	sortedNevFile = fullfile(sortedNevDirectory, [fileName fileExt]);

	% if the sorted nev file exists, use it instead
	if exist(sortedNevFile, 'file');
		fileList{iFile} = sortedNevFile;
	end
end

