function infoValid = checkInfoNev(info, fname, qfname)
% calls delegate functions to determine if a Q struct is still valid based on its info
% if info is empty, loads the info from the q file directly

% find and call the appropriate delegate function to determine whether
% to overwrite this Q file
delegates = getProtocolDelegatesNev();
checkInfoDelegateFn = matchDelegateByFilename(fname, delegates, ...
	'fieldName','checkInfoFn');

if isempty(checkInfoDelegateFn)
	% no delegate function provided
	[path name ext] = fileparts(qfname);
	qfnameShort = [name ext];
	fprintf(2, ...
		'\tWarning: could not find checkInfo handler for %s, assuming valid\n', qfnameShort);
		infoValid = true;
elseif ~isempty(info)
	% call the delegate to figure out if it's valid
	infoValid = checkInfoDelegateFn(info, fname, qfname);
else
		% delegate provided but no info found in this file, assume it's invalid
	infoValid = false;
end

