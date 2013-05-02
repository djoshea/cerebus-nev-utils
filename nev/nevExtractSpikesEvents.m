function [spikeData eventData nevHeader] = nevExtractSpikesEvents(fname, varargin)
% [spikeData eventData nevHeader] = nevExtractSpikesEvents(fname)
%  This function loads a NEV file into matlab using only 
%  script commands. It does not use the neuroshare library.
%  Also loads waveforms into spikeData using nevExtractWaveforms
%  
%  Inputs:
% 
%     fname : filename of the .nev file to open 
% 
%  Outputs:
% 
%   Nx1 where N is number of spikes
%     spikeData.timestamp (in ms)
%     spikeData.electrode
%     spikeData.unit
%     spikeData.waveform
% 
%   Mx1 where M is number of stimulus events:
%     eventData.timestamp (in ms)
%     eventData.why
%     eventData.code
%     eventData.analog
% 
%  Written by Dave Warren, Adapted by Dan O'Shea

% load waveforms for each spike as spikeData.waveform?
def.loadWaveforms = true;

% if specified, keep only spikes from electrodes in this list
def.electrodeList = [];

% if specified, throw away spikes from the zero unit
def.excludeZeroUnit = false;

assignargs(def, varargin);

spikeData = [];
eventData = [];

error(nargchk(1,1,nargin,'struct'));

fprintf('\tLoading spikes from %s\n', fname);

fid = fopen(fname, 'rb');

% Check fid: should be opened as info.fid = fopen(fname, 'rb')
if( fid == -1 ),
   warning( 'Invalid file handle\n' );
   return;
end;

% Read headers
header = nevGetHeaders(fid);
nevHeader = header;

% Figure out how many complete data chunks we can read
fseek(fid, 0, 'eof');
eof = ftell(fid);

% this line throws away one spike at the end, use inf instead
%dataRemaining = floor((eof - (header.dataptr+6)) / header.datasize);
dataRemaining = inf;

% Calculate skip factors based on data size
wavesize = header.datasize - 8;
tsskipsize = header.datasize - 4;
idskipsize = header.datasize - 2;
unitskipsize = header.datasize - 1;

% Read time stamps
if( fseek( fid, header.dataptr, 'bof' ) == -1 ),
   warning( ['Unable to position file, error code ' ferror( fid ) ] );
   return;
end;

% convert to ms
timestamp = fread( fid, dataRemaining, 'uint32', tsskipsize) / header.SampleRes * 1000;

% Read electrode but not unit
if( fseek( fid, header.dataptr+4, 'bof' ) == -1 ),
   warning( ['Unable to position file, error code ' ferror( fid ) ] );
   return;
end;
electrode = fread( fid, dataRemaining, 'uint16=>uint16', idskipsize);

% Read unit but not electrode
if( fseek( fid, (header.dataptr + 6), 'bof' ) == -1 ),
   warning( ['Unable to position file, error code ' ferror( fid ) ] );
   return;
end;
unit = fread( fid, dataRemaining, 'uint8=>uint8', unitskipsize, 'ieee-be' );

% Extract stimulus events
isEvent = electrode == 0;
nEvents = nnz(isEvent);

eventData.timestamp = timestamp(isEvent)';
eventData.why = zeros(nEvents, 1);
eventData.code = zeros(nEvents, 1);
eventData.analog = zeros(nEvents, 5);

% loop over events and read values
eventInds = find(isEvent);
for iev=1:nEvents
  if( fseek( fid, header.dataptr+(eventInds(iev)-1)*header.datasize+6, 'bof' ) == -1 ),
     warning( ['Unable to position file, error code ' ferror( fid ) ] );
     fclose(fid);
     return;
  end;
  
  eventData.why(iev) = fread( fid, 1, 'uint8' );
  fread( fid, 1, 'uint8' );
  eventData.code(iev) = fread( fid, 1, 'uint16' );
  eventData.analog(iev,:) = 1e-3*fread( fid, [1,5], 'int16' );
end

% remove the events to leave spikes 
spikeData.timestamp = timestamp(~isEvent)'; 
spikeData.electrode = electrode(~isEvent)';
spikeData.unit      = unit(~isEvent)';

% load waveforms and check length
if loadWaveforms
    spikeData.waveform = nevExtractWaveforms(fname);
end
assert(size(spikeData.waveform,2) == numel(spikeData.timestamp), ...
    'Different number of waveforms than spikes');

% filter spikes by electrode or unit number?
if excludeZeroUnit || ~isempty(electrodeList)
    keepSpikeInds = true(size(spikeData.timestamp));

    % remove zero unit?
    if excludeZeroUnit
        keepSpikeInds = keepSpikeInds & spikeData.unit ~= 0;
    end

    % select particular electrodes?
    if ~isempty(electrodeList)
        keepSpikeInds = keepSpikeInds & ismember(spikeData.electrode, electrodeList);
    end

    spikeData.timestamp = spikeData.timestamp(keepSpikeInds); 
    spikeData.electrode = spikeData.electrode(keepSpikeInds); 
    spikeData.unit      = spikeData.unit(keepSpikeInds);
    if loadWaveforms
        spikeData.waveform  = spikeData.waveform(:, keepSpikeInds);
    end
end


