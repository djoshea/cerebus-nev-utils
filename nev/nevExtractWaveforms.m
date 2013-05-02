function waves = nevExtractWaveforms(fname)
% waves = nevExtractWaveforms
% Modified from nev2MatWaveforms (Matt Kaufman Stanford University 2010)
% by Dan O'Shea 2011

nPacketsToRead = Inf;
channelsUsed = 1:128;
snippetLen = 32;  % samples per waveform to save down

%% Open .nev file
[fid, message] = fopen(fname, 'rb');
if fid == -1
  warning(['Unable to open file: ' filename ', error message ' message]); %#ok<WNTAG>
  return;
end

%% Read headers
[header, spikeheaders] = nevGetHeaders(fid);
if isempty(header)
  warning(['Unable to read headers in file: ' filename ', error message ' message]); %#ok<WNTAG>
  fclose(fid);
  return;
end

%% Figure out how many bytes per sample in waveforms
waveBytesPerSample = unique([spikeheaders.numberbytes]);
if length(waveBytesPerSample) ~= 1
  error('nevExtractWaveforms: Different units have different sampling of waveforms');
end

%% Figure out scaling factors
% Doesn't deeply need to be unique, but let's hope it is and not write
% the code to handle if it isn't unless we have to.
allScaleFactors = [spikeheaders.sf];
% Convert scaling to uV
scaleFactor = unique(allScaleFactors(channelsUsed)) / 1000;
if length(scaleFactor) ~= 1
  error('nevExtractWaveforms: Different units have different scale factors');
end
    
%% Figure out lockout period
% This is the number of waveform samples divided by the sampling rate,
% converted into ms. This may be overridden at the end if lockout
% violations are found. Violations imply either that RRR was used, which
% has a shorter lockout, or that a buggy version of the Cerebus software
% was used, which can add extraneous events.
snippetLockout = 1000 * ((header.datasize - 8) / waveBytesPerSample) / header.SampleRes;
    
[waves, complete] = nevReadWaveforms(fid, header, waveBytesPerSample, scaleFactor, nPacketsToRead, snippetLen);

if ~complete
    error('nevExtractWaveforms: readNevWaveformsChunk returned complete=false');
end
