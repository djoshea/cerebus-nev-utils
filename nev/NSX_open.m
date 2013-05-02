function [ NSX ] = NSX_open( filename, varargin )
%
%   [ NSX ] = NSX_open( filename, varargin )
%
%   This file opens a CKI NSx file for reading, returning a single
%   structure field containing all the necessary information regarding the
%   the data in the file. This version currently works for both NEV File
%   Specification 2.1 and 2.2.
%
%   Inputs
%
%       filename    -   Name of the file to open, including any path
%                       information. Note: the proper extension (NS1, NS2,
%                       NS3, NS4,or NS5) must be provided.
%
%       any additional arguments will cause information about the file to
%       be printed
%
%   Outputs
%
%       NSX         -   Structure containing details about the file.
%
%  Written by Dave Warren
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
%   magic numbers
%
HeaderString = { 'NEURALSG', 'NEURALCD' };
NEVSpec = [ 2.1, 2.2 ];
BytesPerSample = 2;

%% filesize for NEV Spec 2.1 information
fileinfo = dir( filename );

if( ~exist( filename, 'file' ) )
    warning( 'File %s does not exist', filename );
    NSX = [];
    return;
end

[ NSX.FID, message ] = fopen( filename, 'rb', 'ieee-le' );
if( NSX.FID < 0 )
    warning( 'Unable to open file due to %s', message );
    return
end

%% Read common information across all NEV Spec Versions, allowing deciding which version this file is
ncountTest = 8;[ temp, ncount ] = fread( NSX.FID, [1,ncountTest], 'char' );
if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
NSX.File_Type_ID = char( temp );

NSX.NevSpec = 0;
for n = 1:length( HeaderString )
    if( strcmpi( HeaderString{n}, NSX.File_Type_ID ) )
        NSX.NevSpec = NEVSpec(n);
        break;
    end
end

%% Read file based on which version this conforms to
switch NSX.NevSpec
    case 2.1
        
        %% Read basic header
        ncountTest = 16;[ temp, ncount ] = fread( NSX.FID, [1,ncountTest], 'char');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.File_Spec = char( temp );
        ncountTest = 1;[ NSX.Period, ncount ] = fread( NSX.FID, [1,ncountTest], 'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.Period = 1/30000*NSX.Period;
        ncountTest = 1;[ NSX.Channel_Count, ncount ] = fread( NSX.FID, [1,ncountTest],  'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.header = 8+16+4+4+4*NSX.Channel_Count;
        
        %% Read channel headers
        ncountTest = NSX.Channel_Count;[ NSX.Channel_ID, ncount ] = fread( NSX.FID, [ncountTest,1],  'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        
        %% Fill in data section based on channel number
        NSX.Channel_DigitalMin = int16( zeros( NSX.Channel_Count, 1 ) );
        NSX.Channel_DigitalMax = int16( zeros( NSX.Channel_Count, 1 ) );
        NSX.Channel_AnalogMin = int16( zeros( NSX.Channel_Count, 1 ) );
        NSX.Channel_AnalogMax = int16( zeros( NSX.Channel_Count, 1 ) );
        NSX.Channel_Units = repmat( char(0), NSX.Channel_Count, 16 );
        zNeural = find( NSX.Channel_ID <= 128 );
        if( ~isempty( zNeural ) )
            NSX.Channel_DigitalMin( zNeural, 1 ) = int16( -8191 );
            NSX.Channel_DigitalMax( zNeural, 1 ) = int16(  8191 );
            NSX.Channel_AnalogMin( zNeural, 1 )  = int16( -8191 );
            NSX.Channel_AnalogMax( zNeural, 1 )  = int16(  8191 );
            NSX.Channel_Units( zNeural, : ) = repmat( [ 'uV' repmat( char(0), 1, 14 ) ], length( zNeural), 1 );
        end
        clear zNeural;
        zExpControl = find( NSX.Channel_ID > 128 );
        if( ~isempty( zExpControl ) )
            NSX.Channel_DigitalMin( zExpControl, 1 ) = int16( -32767 );
            NSX.Channel_DigitalMax( zExpControl, 1 ) = int16(  32767 );
            NSX.Channel_AnalogMin( zExpControl, 1 )  = int16( -5000 );
            NSX.Channel_AnalogMax( zExpControl, 1 )  = int16(  5000 );
            NSX.Channel_Units( zExpControl, : ) = repmat( [ 'mV' repmat( char(0), 1, 14 ) ], length( zExpControl), 1 );
        end
        clear zExpControl;
        NSX.Channel_Resolution = ( ...
            ( double( NSX.Channel_AnalogMax  ) - double( NSX.Channel_AnalogMin  ) ) ...
            ./ ...
            ( double( NSX.Channel_DigitalMax ) - double( NSX.Channel_DigitalMin ) ) );
                
        %% Fill in data section data based on only 1 section
        NSX.TimeStamp(1) = 0;
        NSX.TimeResolution = 30000;
        NSX.NumberDataPoints(1) = ( fileinfo.bytes - NSX.header ) / BytesPerSample / NSX.Channel_Count;
        NSX.header(1) = ftell(  NSX.FID );
        NSX.TimeStart(1) = NSX.TimeStamp(1) / NSX.TimeResolution;
        NSX.TimeRange(1) = ( NSX.NumberDataPoints(1) - 1 ) * NSX.Period;
        NSX.TimeEnd(1) = NSX.TimeStart(1) + NSX.TimeRange(1);
        
    case 2.2

        % Read basic header
        ncountTest = 2;[ temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'uchar' );
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        if( ( fix( 10*temp(1) + temp(2) ) / 10 ) ~= NSX.NevSpec )
            warning( 'File specification mismatch' );
            return;
        end
        ncountTest = 1;[ NSX.header, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        ncountTest = 16;[ temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'char');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.File_Spec = char( temp );
        ncountTest = 256;[ temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'char');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.Comment = char( temp );
        ncountTest = 1;[ NSX.Period, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.Period = 1/30000*NSX.Period;
        ncountTest = 1;[ NSX.TimeResolution, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        ncountTest = 16;[ NSX.Time, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint8');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        ncountTest = 1;[ NSX.Channel_Count, ncount ] = fread( NSX.FID, [ncountTest,1],  'uint32');
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        
        %% Read extended channel headers
        for cnt = 1:NSX.Channel_Count
            ncountTest = 2;[ temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'char' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_ID(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 16;[  temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'char' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            NSX.Channel_Label(cnt,:) = char( temp );
            ncountTest = 1;[  NSX.Channel_PhysicalConnector(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint8' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_PhysicalPin(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint8' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_DigitalMin(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'int16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_DigitalMax(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'int16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_AnalogMin(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'int16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_AnalogMax(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'int16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 16;[  temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'char' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            NSX.Channel_Units(cnt,:) = char( temp );
            ncountTest = 1;[  NSX.Channel_HighFreqCorner(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            NSX.Channel_HighFreqCorner(cnt,1) = NSX.Channel_HighFreqCorner(cnt,1) / 1000;
            ncountTest = 1;[  NSX.Channel_HighFreqOrder(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_HighFreqType(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_LowFreqCorner(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            NSX.Channel_LowFreqCorner(cnt,1) = NSX.Channel_LowFreqCorner(cnt,1) / 1000;
            ncountTest = 1;[  NSX.Channel_LowFreqOrder(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
            ncountTest = 1;[  NSX.Channel_LowFreqType(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint16' );
            if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        end;
        NSX.Channel_Resolution = ( ...
            ( double( NSX.Channel_AnalogMax  ) - double( NSX.Channel_AnalogMin  ) ) ...
            ./ ...
            ( double( NSX.Channel_DigitalMax ) - double( NSX.Channel_DigitalMin ) ) );
        
        % read first data packet header
        cnt = 1;
        ncountTest = 1;[  temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint8' );
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        if( temp ~= 1 )
            warning( 'Bad code for start of data header' );
            return;
        end
        ncountTest = 1;[  NSX.TimeStamp(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        ncountTest = 1;[  NSX.NumberDataPoints(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
        if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
        NSX.header(cnt,1) = ftell(  NSX.FID );
        NSX.TimeStart(cnt,1) = NSX.TimeStamp(cnt,1) / NSX.TimeResolution;
        NSX.TimeRange(cnt,1) = ( NSX.NumberDataPoints(cnt,1) - 1 ) * NSX.Period;
        NSX.TimeEnd(cnt,1) = NSX.TimeStart(cnt,1) + NSX.TimeRange(cnt,1);

        %% Read remainding data packet headers
        testPosition = NSX.header(cnt,1) + NSX.NumberDataPoints(cnt,1) * NSX.Channel_Count * BytesPerSample;
        while( testPosition < fileinfo.bytes )
            if( fseek( NSX.FID, testPosition, 'bof' ) >= 0 )
                cnt = cnt + 1;
                ncountTest = 1;[  temp, ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
                if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
                if( temp ~= 1 )
                    warning( 'Bad code for start of data header' );
                    return;
                end
                ncountTest = 1;[  NSX.TimeStamp(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
                if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
                ncountTest = 1;[  NSX.NumberDataPoints(cnt,1), ncount ] = fread( NSX.FID, [ncountTest,1], 'uint32' );
                if( ncount ~= ncountTest );warning( 'Unable to read correct number of elements' );fclose( NSX.FID );NSX.FID = -1;return;end
                NSX.header(cnt,1) = ftell(  NSX.FID );
                NSX.TimeStart(cnt,1) = NSX.TimeStamp(cnt,1) / NSX.TimeResolution;
                NSX.TimeRange(cnt,1) = ( NSX.NumberDataPoints(cnt,1) - 1 ) * NSX.Period;
                NSX.TimeEnd(cnt,1) = NSX.TimeStart(cnt,1) + NSX.TimeRange(cnt,1);
                testPosition = NSX.header(cnt,1) + NSX.NumberDataPoints(cnt,1) * NSX.Channel_Count * BytesPerSample;
            else
                break;
            end
        end
        fseek( NSX.FID, NSX.header(1), 'bof' );
        
    otherwise
        warning( 'Unknown file specification' );
        fclose( NSX.FID );NSX.FID = -1;
        NSX.FID = -1;
        return

end


%% Information output
if nargin > 1
    disp(['File Type ID = ' (NSX.File_Type_ID)]);
    disp(['Label = ' char(NSX.File_Spec)]);
    disp(['Sampling Rate = ' num2str(1/NSX.Period)]);
    disp(['Channel Count = ' num2str(NSX.Channel_Count)]);
end;
    