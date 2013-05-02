function info = parseNevName(fnames)
% info is a struct, or struct array with fields
%   monkey
%   monkeyInitial
%   dateString
%   directory
%   protocol
%   number

if isempty(fnames)
    info = [];
end

if ischar(fnames)
    fnames = {fnames};
end

for i = 1:length(fnames)
    [path name ext] = fileparts(fnames{i});

    % regular expression to match something like Q20110715_DelayedReach001
    ex = '(?<monkeyInitial>[A-Z]+)(?<dateString>\d{8})_(?<protocol>[A-Za-z]+)(?<number>\d{1,5})';
    tokens = regexp(name, ex, 'names');

    if isempty(tokens)
        error('Could not parse nev named %s', name);
    end

    tokens.number = str2num(tokens.number);

    infoThis = tokens;
    infoThis.monkey = lookupMonkeyByInitial(infoThis.monkeyInitial); 
    infoThis.directory = convertDateStringToDirectory(infoThis.dateString);
    info(i) = infoThis;
end
