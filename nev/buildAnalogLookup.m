function analogLookup = buildAnalogLookup(analogInfo, nsxData, varargin)
% lookup the indices of the analog channels and build lookup table to used by
% addRequestedAnalogData.m
%
% analogInfo : 2-deep struct array, 
%   	analogInfo.channelGroupName.channelName = Channel_ID
%   		results in Q(i).channelGroupName.channelName = [ parsed data ]
%   				   Q(i).channelGroupName.time = [ associated time vector ]
%   	analogInfo.channelGroupName = [ Channel_ID List ]
%   		results in Q(i).channelGroupName.data = [data matrix]
%   				   Q(i).channelGroupName.
%   				   Q(i).channelGroupName.time = [ time vector]
%       all channels within a channelGroup must come from the same nsxFile (same element of nsxData)
%
% analogLookup(i) has fields
%    .groupName
%    .name
%    .nsxIndex
%    .chInd : nsxData(nsxIndex).data(chInd, :) are these channels' data
%    .single : false for multiple channels (chId is plural)
%    .lookup : for mutliple channels only, the lookup table corresponding to the elements of chInd
%               i.e. data(chInd(i), :) corresponds to analogInfo.group( .lookup (i) )
%              this is necessary because not all channels in the analogInfo.group array may be found

par.suppressNotFoundWarningsForGroups = {'lfp'};
assignargs(par, varargin);

fprintf('\tBuilding analog channel lookup table\n');

analogLookup = [];

channelGroups = fieldnames(analogInfo);
nChannelGroups = length(channelGroups);
for icg = 1:nChannelGroups
    groupName = channelGroups{icg};
    group = analogInfo.(groupName);
    if isempty(group)
        continue;
    end
    
    if isstruct(group)
        % a group of single channel named lookups
        names = fieldnames(group);
        groupInsx = [];
        groupScaleLims = [];
        
        % loop over analog channels in this group
        for ic = 1:length(names)
            
            % find this particular analog channel by its number in NSX.Channel_ID
            name = names{ic};
            id = group.(name);
            found = false;

            % loop thru the nsx files looking for this channel
            for insx = 1:length(nsxData)
                channelIdList = nsxData(insx).channelIds;
                ind = find(channelIdList == id); 
                if ~isempty(ind)
                    % found this channel or one of the channels
                    % verify it's in the same nsx as the others in group
                    if isempty(groupInsx) || groupInsx == insx
                        % in the same nsx, assign into the lookup table
                        lookup.groupName = groupName;
                        lookup.name = name;
                        lookup.nsxIndex = insx;
                        lookup.chInd = ind;
                        lookup.single = true;
                        lookup.lookup = [];
                        lookup.scaleFn = nsxData(insx).scaleFns{ind};
                        lookup.scaleLims = nsxData(insx).scaleLims{ind};

                        % check that scaleLims are consistent within this group
                        if ~isempty(groupScaleLims) && any(lookup.scaleLims ~= groupScaleLims)
                            error('Channel %s.%s has different scale limits than other channels in group', ...
                                groupName, name);
                        end

                        groupInsx = insx;
                        groupScaleLims = lookup.scaleLims;

                        found = true;
                        break;
                    else
                        % not in the same nsx as others in the group
                        error('Channel %s.%s not found in nsx %s, others in group found in %s', ...
                            groupName, name, nsxData(insx).ext, nsxData(groupInsx).ext);
                    end
                end
            end
            
            if ~found
                % couldn't find it, warning and exclude this channel
                fprintf('\t\tWarning: could not find analog channel %s (%d)\n', name, id);
            else
                % found it, add to the lookup list
                if isempty(analogLookup)
                    analogLookup = lookup;
                else
                    analogLookup(end+1) = lookup;
                end
            end
        end
        
    else
        % multiple channel lookup to be squashed into one array
        ids = group;
        lookup.single = false;
        found = false;

        groupScaleLims = [];
        
        % loop thru the nsx files looking for any channel in list
        for insx = 1:length(nsxData)
            channelIdList = nsxData(insx).channelIds;
            ind = find(ismember(channelIdList, ids)); 
            if ~isempty(ind)
                % found one of the channels
                found = true;
                lookup.groupName = groupName;
                lookup.name = '';
                lookup.nsxIndex = insx;
                lookup.single = false;

                % now search for each of the channels and build a lookup table
                lookup.lookup = [];
                lookup.chInd = [];
                for iid = 1:length(ids)
                    id = ids(iid);
                    ind = find(channelIdList == id);
                    if isempty(ind)
                        % warn that we couldn't find this channel unless warnings are suppressed for this group
                        if ~ismember(groupName, suppressNotFoundWarningsForGroups)
                            fprintf('\tWarning: could not find channel %d for group %s\n', ...
                                id, groupName);
                        end
                    else
                        % we found this channel
                        lookup.chInd(end+1, 1) = ind;
                        % which channel in the requested list are we adding? this is necessary because we skip channels we can't find
                        lookup.lookup(end+1, 1) = iid; 

                        % get the scaling limits
                        lookup.scaleLims = nsxData(insx).scaleFns{ind};
                        lookup.scaleLims = nsxData(insx).scaleLims{ind};

                        % check that they are consistent for this group
                        if ~isempty(groupScaleLims) && any(groupScaleLims ~= lookup.scaleLims)
                            error('Channel Id %d in group %s has different scale limits than other channels in group', ...
                                id, groupName);
                        end

                    end
                end
                
                break;
            end
        end
            
        if ~found
            % couldn't find it, warning and exclude this channel
            fprintf('\t\tWarning: could not find any channels for group %s\n', groupName);
        else
            % found it, add to the lookup list
            if isempty(analogLookup)
                analogLookup = lookup;
            else
                analogLookup(end+1) = lookup;
            end
        end
    end
end
