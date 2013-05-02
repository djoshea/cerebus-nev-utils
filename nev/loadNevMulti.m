function [Qcell infoCell] = loadNevMulti(fnameList, varargin)

if ~exist('fnameList', 'var') || isempty(fnameList)
    startDir = getPathToData('monkeyRoot');
    fnameList = filePicker([], 'filterList', {'*.nev', 'Cerebus Files (*.nev)'}, 'multiple', true, ...
        'prompt', 'Choose NEV File(s)', 'selectMode', 'file', 'extensionFilter', '*.nev', 'startDir', startDir);

end

% check for existence of all file
for ifile = 1:length(fnameList)
    if ~exist(fnameList{ifile}, 'file')
        error('Could not find file %s', fnameList{ifile});
    end
end

% load each nev file
for ifile = 1:length(fnameList)
    [Qcell{ifile} infoCell{ifile}] = loadNev(fnameList{ifile}, varargin{:});
end

end
