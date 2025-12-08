set nocount on;

if object_id('tempdb..#WrestlerLookup') is not null
	drop table #WrestlerLookup;

select	EventWrestlerID = min(EventWrestlerMatch.EventWrestlerID)
		, LookupName = replace(trim(EventWrestlerMatch.WrestlerName), ' ', '')
		, LookupTeam = replace(replace(replace(replace(replace(EventWrestlerMatch.TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
into	#WrestlerLookup
from	EventWrestlerMatch
where	len(trim(EventWrestlerMatch.WrestlerName)) between 3 and 40
group by
		replace(trim(EventWrestlerMatch.WrestlerName), ' ', '')
		, replace(replace(replace(replace(replace(EventWrestlerMatch.TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')

create index idx_WrestlerLookup_LookupName on #WrestlerLookup (LookupName);

set nocount off;