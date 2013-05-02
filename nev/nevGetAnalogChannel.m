function [time data samplingHz] = nevGetAnalogChannel(nevFile, channelInd)
% [time data] = nevGetAnalogChannel(nevFile, channelInd)
% returns a single channel's analog data from a single nev file by channel id

    nsxData = nevExtractAnalog(nevFile);
    analogInfo.broadband = channelInd;
   
    lookup = buildAnalogLookup(analogInfo, nsxData);

    nsxData = nsxData(lookup.nsxIndex);
    samplingHz = nsxData.samplingHz;
    time = nsxData.time;
    dataOrig = nsxData.data(lookup.chInd, :);
    data = nsxData.scaleFns{lookup.chInd}(dataOrig);

