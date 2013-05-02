function Q = loadNev_Generic(filename, varargin)

type = [];
version = [];
par.trialSegmentationInfo = [];
par.analogInfo = [];
par.eventInfo = [];
par.trialIdFn = [];
par.type = []; % gets assigned as .type to each element of Q
par.version = []; % gets assigned as .version to each element of Q

par.spikeWindowPre = 0; % time before trial start to grab spikes from 
par.spikeWindowPost = 0; % time after trial end to grab spikes from

par.nsxExts = {'.ns1', '.ns2', '.ns3', '.ns4', '.ns5'};
assignargs(par, varargin);

if isempty(trialSegmentationInfo)
    error('No trialSegmentationInfo specified');
end

[path name ext] = fileparts(filename);

% append .nev extension if necessary
if isempty(ext) || ~strcmp(ext, '.nev')
    filenameNev = [filename '.nev'];
else
    filenameNev = filename;
end

% load spiking data from the nev file
[spikeData eventData] = nevExtractSpikesEvents(filenameNev);

% figure out which analog channel ids to load to save memory
channelIdList = buildAnalogChannelIdList(analogInfo);

% load analog data from nsx files
nsxData = nevExtractAnalog(filenameNev, 'channelIds', channelIdList, 'nsxExts', nsxExts);

% Do trial segmentation
trialInfo = getTrialSegmentation(trialSegmentationInfo, spikeData, eventData, nsxData);

% Use this trialInfo to build a Q with .CerebusInfo
Q = segmentTrials(trialInfo);

% Add the nev file name to CerebusInfo
for iQ = 1:length(Q)
    Q(iQ).CerebusInfo.nevFile = filenameNev;
end

% segment spikes and waveforms
Q = addSegmentedSpikes(Q, spikeData, 'spikeWindowPre', spikeWindowPre, 'spikeWindowPost', spikeWindowPost);
clear spikeData;

% add the analog channels in nicely formatted channel groups
% with time vectors and lookup tables
Q = addSegmentedAnalog(Q, analogInfo, nsxData);
clear analogInfo;
clear nsxData;
    
% grab events within time period
Q = addSegmentedEvents(Q, eventInfo, eventData); 
clear eventInfo;
clear eventData;

if ~isempty(Q)
    % Add trial ids according to callback function provided
    if ~isempty(trialIdFn) 
        for iq = 1:length(Q)
            Q(iq).trialId = trialIdFn(Q(iq));
        end
    else
        % empty by default
        [Q.trialId] = deal([]);
    end

    % Add .type and .version fields as specified
    [Q.type] = deal(type);
    [Q.version] = deal(version);

    % include short nev file name in CerebusInfo field 
    for iq = 1:length(Q)
        Q(iq).CerebusInfo.nevNameShort = [name ext];
    end
end

