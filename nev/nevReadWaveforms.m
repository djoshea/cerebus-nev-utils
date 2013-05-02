function [waveforms, complete] = readNevWaveformsChunk(fid, header, waveBytesPerSample, scaleFactor, nPacketsToRead, snippetLen)
%
%  [waveforms, complete] = readNevWaveformsChunk(fid, header, waveBytesPerSample, scaleFactor, nPacketsToRead, snippetLen);
%
%  This function converts a chunk of a NEV file into matlab using only
%  script commands. Includes waveforms.
%  
%  Inputs:
%
%     fid        - a file handle to an open .nev file (read-only, binary).
%                  Should be open to the start of a data packet.
%
%     header     - header from the .nev file
%
%     waveBytesPerSample - how many bytes in each sample of the waveform.
%                          Should be gotten from the spikeheaders.
%
%     scaleFactor - conversion factor between values stored in .nev file
%                   and uV (note: this is 1000 x what is in the
%                   spikeheaders)
%
%     nPacketsToRead - number of packets to read from the file. Will
%                      probably return fewer waveforms, since some packets
%                      are digital I/O!
%
%     snippetLen - length of each snippet. Probably 32.
%
%  Outputs:
%
%     waveforms - A nPts by W array of waveforms data, matched up with the
%                 spikes data. W will be <= nPacketsToRead.
%
%     complete  - 1 if this was the last chunk of the file, 0 otherwise
%
%
%

% Make sure that the output exists
waveforms = [];

% Check input arguments
if nargin ~= 6, warning('6 inputs required'); return; end;

if fid == -1
  warning('.nev file not open!');
  return;
end;

% Calculate skip factors based on data size
wavesize = header.datasize - 8;
idskipsize = header.datasize - 2;
nonWaveSize = 8;

% Figure out how many packets are left
startPos = ftell(fid);
fseek(fid, 0, 'eof');
endPos = ftell(fid);
nPacketsLeft = (endPos - startPos) / header.datasize;
nPacketsToRead = min(nPacketsLeft, nPacketsToRead);
if nPacketsToRead == nPacketsLeft
  complete = 1;
else
  complete = 0;
end

% Read appropriate number of electrode IDs, to exclude non-waveform entries
if fseek(fid, startPos+4, 'bof') == -1
   warning( ['Unable to position file, error code ' ferror(fid) ] );
   fclose(fid);
   return;
end;
electrodeIDs = fread(fid, nPacketsToRead, 'uint16=>uint16', idskipsize);

% Grab waveforms
if fseek(fid, startPos+8, 'bof') == -1
   warning(['Unable to position file, error code ' ferror(fid)]);
   fclose(fid);
   return;
end;
if waveBytesPerSample == 2
  waveSamples = wavesize/waveBytesPerSample;
  waveforms = fread(fid, [waveSamples, nPacketsToRead], sprintf('%d*int16=>int16', waveSamples), nonWaveSize);
  if scaleFactor ~= 1
	  fprintf('non uniform scale factor!\n');
    waveforms = waveforms * scaleFactor;
  end
else
  fclose(fid);
  error('readNevWaveformsChunk: waveforms samples are not 2 bytes wide');
end

% Now, when we use fread with a 'count' value (2nd argument) of the form
% [m, n], the byte-skipping is done not only between entries but also an
% extra one is done at the end. So, we need to back up by one skip value so
% that we'll be in the right place for the next chunk (if applicable).
fseek(fid, -nonWaveSize, 'cof');

% Toss non-waveform entries, which will contain junk
% Use logical indexing for speed
snippetPts = logical([ones(1, snippetLen) zeros(1, size(waveforms, 1) - snippetLen)]);
waveforms = waveforms(snippetPts, logical(electrodeIDs));
