function [Q info] = loadNev_Example(fname, varargin)
    % [Q info] = loadNev_Example(fname, varargin)

    % timestamp based versioning, will be stored in each trial
    info.version = 20130512;

    % call with no arguments to get the current version
    if nargin == 0
        Q = [];
        return;
    end

    % protocol name goes here
    protocol = 'exampleProtocol';

    % trial segmentation, here based on serial line code pattern matching
    % there are other modes available, files matching getTrialSegmentation_%s.m are different methods 
    trialSeg.mode = 'StartEndPatterns';
    % start code, 2x trial code, 2x trial type, acquired touch code
    trialSeg.startPattern = [32768 NaN NaN NaN NaN 32769];
    trialSeg.endPattern = 0;
    trialSeg.maxTrialLength = 10e3; % ms

    % time before the start and end of each trial to grab spikes, for the purposes of filtering without artifacts
    % (at the moment there is no equivalent functionality for analog channels)
    spikeWindowPre = 0;
    spikeWindowPost = 0;

    % analog info: syntax is as follows
    % analogInfo.groupName.channelName = channelNumber
    % will store the data as Q(iQ).groupName.channelName = data;
    analogInfo.analog.red = 129;
    analogInfo.analog.yellow = 130;
    analogInfo.analog.green = 131;
    analogInfo.analog.blue = 132;
    analogInfo.analog.photobox = 137;
    analogInfo.broadband.estim = 133;
    analogInfo.lfp = 1:128; % will store all channels in [1:128] in a large matrix with a lookup table

    % event code translation: none
    eventInfo.lowOrderByte = true; % strip high order bits from serial code?
    eventInfo.skipPulsesStart = 5; % number of pulses in event stream to skip before parsing event codes
    eventInfo.skipPulsesEnd = 1;

    % list of serial codes and name
    eventInfo.codes.acqTouch = 1;
    eventInfo.codes.heldTouch = 2;
    eventInfo.codes.nominalGoCue = 3;
    eventInfo.codes.acqTarget = 4;
    eventInfo.codes.heldTarget = 5;
    eventInfo.codes.nominalStimStart = 12;
    eventInfo.codes.onlineMoveOnset = 13;
    eventInfo.codes.success = 100;
    eventInfo.codes.failHoldTouch = 101;
    eventInfo.codes.failBrokeTouchBeforeCue = 102;
    eventInfo.codes.failDidntAcqTarget = 103;
    eventInfo.codes.failDidntHoldTarget = 105;
    eventInfo.codes.failRTTooFast = 106;
    eventInfo.codes.failRTTooSlow = 107;

    % Trial Id Function: maps each trial's struct to a trial Id
    % here: concatenate the low order bytes of the second and third 
    % codes in the stream, not skipping the initial pulses
    trialIdFn = @(q) bitor(bitshift(bitand(q.evc.rawPulses(2), 255), 8), ...
        bitand(q.evc.rawPulses(3), 255));

    % loadNev_Generic does all the work, by means of calling a slew of subfunctions
    % the purpose of this function is just to build out the right arguments for it
    Q = loadNev_Generic(fname, 'trialSegmentationInfo', trialSeg, ... 
        'analogInfo', analogInfo, 'eventInfo', eventInfo, ...
        'trialIdFn', trialIdFn, 'type', protocol, 'version', info.version, ...
        'spikeWindowPre', spikeWindowPre, 'spikeWindowPost', spikeWindowPost);
end

