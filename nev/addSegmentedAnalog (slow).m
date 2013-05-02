function [Q analogLookup] = addFormattedAnalogData(Q, analogInfo, nsxData)
	% grab analog data according to analogLookup, 
	% subtract time offset, parse into channel groups,
	% assign into struct

    % build the lookup table which tells us where to find (in nsxData) each
    % requested analog channel to speed things up a biq

    analogLookup = buildAnalogLookup(analogInfo, nsxData);

    % we first want to split the data into multiple facets

    textprogressbar('Adding segmented analog data');
	for iq = 1:length(Q)
        textprogressbar(iq / length(Q));

        % precompute the segmented data for this trial
        for insx = 1:length(nsxData)
            timeInds = nsxData(insx).time >= Q(iq).CerebusInfo.startTime & ...
                       nsxData(insx).time <= Q(iq).CerebusInfo.endTime;
            data{insx} = nsxData(insx).data(:, timeInds);
            timeOffset{insx} = nsxData(insx).time(timeInds) - Q(iq).CerebusInfo.startTime;
        end
        
		% look over each analog channel/channel set requested
		for ia = 1:length(analogLookup)
			lk = analogLookup(ia);
			insx = lk.nsxIndex;
			% check for time field in this channel group, add if missing
			if ~isfield(Q(iq), lk.groupName) || ~isfield(Q(iq).(lk.groupName), 'time') || isempty(Q(iq).(lk.groupName).time)
				Q(iq).(lk.groupName).time = makerow( ...
                    nsxData(insx).time( nsxData(insx).time >= Q(iq).CerebusInfo.startTime & ...
                                        nsxData(insx).time <= Q(iq).CerebusInfo.endTime ) - ...
                                        Q(iq).CerebusInfo.startTime );
			end

			% check for scaleFn and scaleLims field in this channel group, add if missing
			if ~isfield(Q(iq), lk.groupName) || ~isfield(Q(iq).(lk.groupName), 'scaleFn') || isempty(Q(iq).(lk.groupName).scaleFn)
				Q(iq).(lk.groupName).scaleFn = lk.scaleFn;
                Q(iq).(lk.groupName).scaleLims = lk.scaleLims;
			end

            % figure out how to assign the data (single or multiple channel assign with lookup?)
			if(lk.single)
				% single channel assign into group
                dataName = lk.name;
            else
				% multiple channels: assign into matrix, include lookup table
                dataName = 'data';
				Q(iq).(lk.groupName).lookup = lk.lookup;
            end

            % actually assign the data for this channel or channel set
            Q(iq).(lk.groupName).(dataName) = nsxData(insx).data(lk.chInd, ...
                   nsxData(insx).time >= Q(iq).CerebusInfo.startTime & ...
                   nsxData(insx).time <= Q(iq).CerebusInfo.endTime);
		end
    end
    textprogressbar('done', true);
end

