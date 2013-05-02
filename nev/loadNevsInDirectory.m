function [Qcell infoCell fileList] = loadNevsInDirectory(directory, varargin)

% locate the data directory
if ~exist('directory', 'var')
	directory = '';
end
directory = checkOrPromptDataDirectory(directory);

fileList = listNevsInDirectory(directory);

if isempty(fileList)
    fprintf('\tWarning: no .nev files found in %s\n', directory);
    Qcell = {};
    infoCell = {};
    fileList = {};
    return;
end

[Qcell infoCell] = loadNevMulti(fileList, varargin{:});

end
