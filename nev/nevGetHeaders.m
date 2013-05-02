function [ nevheader, spikeheader, nevstimheader ] = nevGetHeaders( fid )
%
%	function [ nevheader, spikeheader, nevstimheader ] = NEVGetHeaders( fid )
%
%  Reads the header data from a nev file - see the nev spec for interpretation
%
%  Written by Dave Warren

nevheader =[];
spikeheader= [];
nevstimheader= [];

if( nargin ~= 1 );
   warning( 'Incorrect number of input arguments' );
   return;
end;

if( fid < 0 )
   warning( 'Invalid file handle' );
   return;
end;

%	Position file to beginning
if( fseek( fid, 0, 'bof' ) == - 1 ),
   warning( 'Invalid file positioning' );
   return;
end;

%	Read Headers
nevheader.id = char (fread( fid, 8, 'char' ))';
nevheader.filespec = fread( fid, 1, 'uint16' );
nevheader.fileformat = fread( fid, 1, 'uint16' );
nevheader.dataptr = fread( fid, 1, 'uint32' );
nevheader.datasize = fread( fid, 1, 'uint32' );
nevheader.TimeRes = fread( fid, 1, 'uint32' );
nevheader.SampleRes = fread( fid, 1, 'uint32' );
nevheader.FileTime = fread( fid, 8, 'uint16' );
nevheader.AppName = char (fread( fid, 32, 'char' ))';
nevheader.Comment = char (fread( fid, 256, 'char' ))';
nevheader.NumHeaders = fread( fid, 1, 'uint32' );

for n=1:nevheader.NumHeaders;
   HeaderName = char (fread( fid, 8, 'char' ));
   if( strncmp( HeaderName, 'NEUEVWAV', 8 ) == 1 ),
      id = fread( fid, 1, 'uint16' );
      spikeheader(id).id = id;
      spikeheader(id).pinch = fread( fid, 1, 'uint8' );
      spikeheader(id).pinnum = fread( fid, 1, 'uint8' );
      spikeheader(id).sf = fread( fid, 1, 'uint16' );
      spikeheader(id).energythreshold = fread( fid, 1, 'int16' );
      spikeheader(id).highthreshold = fread( fid, 1, 'int16' );
      spikeheader(id).lowthreshold = fread( fid, 1, 'int16' );
      spikeheader(id).numberunits = fread( fid, 1, 'uint8' );
      spikeheader(id).numberbytes = fread( fid, 1, 'uint8' );
      spikeheader(id).dummy = fread( fid, 10, 'uint8' );
   else,
      if( or( (strncmp( HeaderName, 'NSASEXEV', 8 ) == 1) , (strncmp( HeaderName, 'STIMINFO', 8 ) == 1) ) ),
         nevstimheader.PeriodicRes = fread( fid, 1, 'uint16' );
         nevstimheader.DigitalConfig = fread( fid, 1, 'uint8' );
         for m=1:5;
            nevstimheader.AnalogConfig(m).Config = fread( fid, 1, 'uint8' );
            nevstimheader.AnalogConfig(m).Level = fread( fid, 1, 'int16' );
         end;
         nevstimheader.dummy = fread( fid, 6, 'uint8' );
      else,
         dummy = fread( fid, 24, 'char' );
      end;
   end;
end;

return;



   
