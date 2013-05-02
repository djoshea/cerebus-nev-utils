function nsxData = nevExtractAnalog(fname, varargin)
% nsxData = nevExtractAnalog(fname)
%   Loads analog data from all nsx files associated with fname (.nev)
%
% fname : name of nev file (or without extension)
% nsxData : struct array, one element for each located ns# file with the same path/name as fname
%   .fname
%   .info : header info as returned from NSX_open
%   .ext : the ns# extension
%   .samplingHz : sampling frequency converted from nsx headers
%   .data : all channels 
%   .time : in ms
%   .timeStart, .timeSamplePeriod: starting point and inter-sample interval in ms
%   .scaleFn : scaleFn(data) returns a double that has been converted into the correct units
%   .scaleLims : [ digitalMin digitalMax analogMin analogMax ] limits used to build scaleFn

par.nsxExts = {'.ns1', '.ns2', '.ns3', '.ns4', '.ns5'};
par.rescale = true; % convert to actual units indicated, uses more memory (double instead of int16)
par.channelIds = []; % select channels by Channel_ID to keep, throw away the rest
assignargs(par, varargin);

[path name ext] = fileparts(fname);

if isempty(path)
    error('Please provide absolute, not relative, path to file');
end

% if this is a sorted nev file, we'll find the nsx files in the parent directory,
% where the original, raw nev file is located
% if checkNevInSortedDirectory(fname)
%     % it's sorted, look in parent directory
%     nsxPath = fileparts(path);
% else
%     nsxPath = path;
% end
nsxPath = path;

% find existing .nsX files (which hold continuous data)
% attempt each nsx extension to find analog data
nsxCount = 0;

for iext = 1:length(nsxExts)
    fnameSearch = fullfile(nsxPath, [name nsxExts{iext}]);
    if exist(fnameSearch, 'file')
        % an nsx file with this extension exists, load it up
        nsxCount = nsxCount + 1;

        fprintf('\tLoading analog from %s\n', fnameSearch);
        nsxInfo = NSX_open(fnameSearch);

        nsxData(nsxCount).fname = fnameSearch;
        nsxData(nsxCount).info = nsxInfo; 
        nsxData(nsxCount).ext = nsxExts{iext};
        nsxData(nsxCount).samplingHz = sscanf(nsxInfo.File_Spec, '%d kS/s') * 1000;
        [data time timeStart timeSamplePeriod] = NSX_read(nsxInfo);
        
        if isempty(channelIds)
            % keep all channels
            nsxData(nsxCount).data = int16(data);
            nsxData(nsxCount).channelIds = nsxInfo.Channel_ID;
            channelIndsIncluded = 1:size(data,1);
        else
            channelIdsThisFile = [];
            channelIndsIncluded = [];
            for ich = 1:length(channelIds)
                chId = channelIds(ich);
                ind = find(nsxInfo.Channel_ID == chId);
                if ~isempty(ind)
                    % found it, store the inde
                    channelIdsThisFile = [channelIdsThisFile chId];
                    channelIndsIncluded = [channelIndsIncluded ind];
                end
            end
       
            nsxData(nsxCount).data = int16(data(channelIndsIncluded, :));
            nsxData(nsxCount).channelIds = channelIdsThisFile;
       end 
        
        nsxData(nsxCount).time = makerow(time * 1000); % convert to ms
        nsxData(nsxCount).timeStart = timeStart * 1000;
        nsxData(nsxCount).timeSamplePeriod = timeSamplePeriod * 1000;

        % this function rescales to be in the correct units, but uses more memory
        [nsxData(nsxCount).scaleFns nsxData(nsxCount).scaleLims] = getScaleFns(nsxInfo, channelIndsIncluded); 

        NSX_close(nsxInfo);
    end
end

if nsxCount == 0
    nsxData = [];
end

end

function [scaleFns scaleLims] = getScaleFns(nsxInfo, channelInds)
    [scaleFns scaleLims] = deal(cell(length(channelInds), 1));
    for ich = 1:length(channelInds)
        ind = channelInds(ich);
        origLims = double([nsxInfo.Channel_DigitalMin(ind) nsxInfo.Channel_DigitalMax(ind)]);
        newLims  = double([nsxInfo.Channel_AnalogMin(ind)  nsxInfo.Channel_AnalogMax(ind)]);
        scaleLims{ich} = [origLims newLims];
        scaleFns{ich} = @(signal) (double(signal) - origLims(1)) / ...
                                   diff(origLims) * diff(newLims) + newLims(1);
    end
end
