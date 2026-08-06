set nocount on

if object_id('tempdb..#WrestlerLookup') is not null
	drop table #WrestlerLookup;

-- Build the full lookup table
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

-- Wipe out any invalid sql ids so it can try to re-attach
update	#WrestlingPortalMatches
set		WinnerWrestlerID = null
from	#WrestlingPortalMatches WrestlingPortalMatches
left join
		EventWrestler
on		WrestlingPortalMatches.WinnerWrestlerID = EventWrestler.ID
where	WrestlingPortalMatches.WinnerWrestlerID is not null
		and EventWrestler.ID is null;

update	#WrestlingPortalMatches
set		LoserWrestlerID = null
from	#WrestlingPortalMatches WrestlingPortalMatches
left join
		EventWrestler
on		WrestlingPortalMatches.LoserWrestlerID = EventWrestler.ID
where	WrestlingPortalMatches.LoserWrestlerID is not null
		and EventWrestler.ID is null;

if object_id('tempdb..#PortalWrestler') is not null
	drop table #PortalWrestler;

create table #PortalWrestler (
	WrestlerName varchar(255)
	, TeamName varchar(255)
	, LookupName varchar(255)
	, LookupTeam varchar(255)
)

-- Load the unique list of wrestlers without an ID
insert	#PortalWrestler (
		WrestlerName
		, TeamName
		, LookupName
		, LookupTeam
		)
select	distinct 
		WrestlerName = WrestlingPortalMatches.WinnerName
		, TeamName = WrestlingPortalMatches.WinnerTeam
		, LookupName = replace(trim(WrestlingPortalMatches.WinnerName), ' ', '')
		, LookupTeam = replace(replace(replace(replace(replace(WrestlingPortalMatches.WinnerTeam, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
from	#WrestlingPortalMatches WrestlingPortalMatches
where	WrestlingPortalMatches.WinnerWrestlerID is null
		and WrestlingPortalMatches.WinnerName <> 'Forfeit'
		and len(WrestlingPortalMatches.WinnerName) > 0
union
select	distinct 
		WrestlerName = WrestlingPortalMatches.LoserName
		, TeamName = WrestlingPortalMatches.LoserTeam
		, LookupName = replace(trim(WrestlingPortalMatches.LoserName), ' ', '')
		, LookupTeam = replace(replace(replace(replace(replace(WrestlingPortalMatches.LoserTeam, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
from	#WrestlingPortalMatches WrestlingPortalMatches
where	WrestlingPortalMatches.LoserWrestlerID is null
		and WrestlingPortalMatches.LoserName <> 'Forfeit'
		and len(WrestlingPortalMatches.LoserName) > 0

if object_id('tempdb..#WrestlerMatch') is not null
	drop table #WrestlerMatch;

-- Find the matching wrestlers
select	PortalWrestler.WrestlerName
		, PortalWrestler.TeamName
		, WrestlerLookup.EventWrestlerID
into	#WrestlerMatch
from	#PortalWrestler PortalWrestler
join	#WrestlerLookup WrestlerLookup
on		PortalWrestler.LookupName = WrestlerLookup.LookupName
		and PortalWrestler.LookupTeam = WrestlerLookup.LookupTeam;

-- Upddate the winner records
update	#WrestlingPortalMatches
set		WinnerWrestlerID = WrestlerMatch.EventWrestlerID
from	#WrestlingPortalMatches WrestlingPortalMatches
join	#WrestlerMatch WrestlerMatch
on		WrestlingPortalMatches.WinnerName = WrestlerMatch.WrestlerName
		and WrestlingPortalMatches.WinnerTeam = WrestlerMatch.TeamName
		and WrestlingPortalMatches.WinnerWrestlerID is null

-- Update the loser records
update	#WrestlingPortalMatches
set		LoserWrestlerID = WrestlerMatch.EventWrestlerID
from	#WrestlingPortalMatches WrestlingPortalMatches
join	#WrestlerMatch WrestlerMatch
on		WrestlingPortalMatches.LoserName = WrestlerMatch.WrestlerName
		and WrestlingPortalMatches.LoserTeam = WrestlerMatch.TeamName
		and WrestlingPortalMatches.LoserWrestlerID is null


begin transaction

begin try

update	Event
set		EventSystem = 'WrestlingPortal'
		, SystemID = WrestlingPortalMatches.SystemID
		, EventName = WrestlingPortalMatches.EventName
		, EventDate = try_cast(WrestlingPortalMatches.EventDate as datetime)
		, EventAddress = coalesce(WrestlingPortalMatches.EventAddress, '')
		, EventState = WrestlingPortalMatches.EventState
		, IsComplete = 1
		, IsExcluded = 0
		, ModifiedDate = getdate()
from	Event
join	#WrestlingPortalMatches WrestlingPortalMatches
on		Event.ID = WrestlingPortalMatches.EventID

insert	Event (
		EventSystem
		, SystemID
		, EventName
		, EventDate
		, EventAddress
		, EventState
		, IsComplete
		, IsExcluded
		, InsertDate
		, ModifiedDate
		)
select	distinct EventSystem = 'WrestlingPortal'
		, SystemID = WrestlingPortalMatches.SystemID
		, EventName = WrestlingPortalMatches.EventName
		, EventDate = try_cast(WrestlingPortalMatches.EventDate as datetime)
		, EventAddress = coalesce(WrestlingPortalMatches.EventAddress, '')
		, EventState = WrestlingPortalMatches.EventState
		, IsComplete = 1
		, IsExcluded = 0
		, InsertDate = getdate()
		, ModifiedDate = getdate()
from	#WrestlingPortalMatches WrestlingPortalMatches
where	WrestlingPortalMatches.EventID is null

delete
from	EventMatch
where	EventID in (
		select	ID
		from	#WrestlingPortalMatches WrestlingPortalMatches
		join	Event
		on		WrestlingPortalMatches.systemid = Event.SystemID
				and Event.EventSystem = 'WrestlingPortal'

		)

insert	EventMatch (
		EventID
		, Division
		, WeightClass
		, WinType
		, Sort
		, InsertDate
		, ModifiedDate
		)
select	EventID = Event.ID
		, Division = WrestlingPortalMatches.Division
		, WeightClass = WrestlingPortalMatches.WeightClass
		, WinType = WrestlingPortalMatches.WinType
		, Sort = WrestlingPortalMatches.Sort
		, InsertDate = getdate()
		, ModifiedDate = getdate()
from	#WrestlingPortalMatches WrestlingPortalMatches
join	Event
on		WrestlingPortalMatches.SystemID = Event.SystemID
		and Event.EventSystem = 'WrestlingPortal'

insert	EventWrestlerMatch (
		EventMatchID
		, EventWrestlerID
		, WrestlerName
		, TeamName
		, IsWinner
		, Takedowns
		, Escapes
		, Nearfalls
		, Reversals
		, InsertDate
		, ModifiedDate
		)
select	EventMatchID = EventMatch.ID
		, EventWrestlerID = WrestlingPortalMatches.WinnerWrestlerID
		, WrestlerName = WrestlingPortalMatches.WinnerName
		, TeamName = WrestlingPortalMatches.WinnerTeam
		, IsWinner = 1
		, Takedowns = WrestlingPortalMatches.WinnerTakedowns
		, Escapes = WrestlingPortalMatches.WinnerEscapes
		, Nearfalls = WrestlingPortalMatches.WinnerNearFalls
		, Reversals = WrestlingPortalMatches.WinnerReversals
		, InsertDate = getdate()
		, ModifiedDate = getdate()
from	#WrestlingPortalMatches WrestlingPortalMatches
join	Event
on		WrestlingPortalMatches.SystemID = Event.SystemID
		and Event.EventSystem = 'WrestlingPortal'
join	EventMatch
on		EventMatch.EventID = Event.ID
		and WrestlingPortalMatches.WeightClass = EventMatch.WeightClass
		and WrestlingPortalMatches.Division = EventMatch.Division
		and WrestlingPortalMatches.WinType = EventMatch.WinType
		and WrestlingPortalMatches.Sort = EventMatch.Sort
where	WrestlingPortalMatches.WinnerWrestlerID is not null
union
select	EventMatchID = EventMatch.ID
		, EventWrestlerID = WrestlingPortalMatches.LoserWrestlerID
		, WrestlerName = WrestlingPortalMatches.LoserName
		, TeamName = WrestlingPortalMatches.LoserTeam
		, IsWinner = 0
		, Takedowns = WrestlingPortalMatches.LoserTakedowns
		, Escapes = WrestlingPortalMatches.LoserEscapes
		, Nearfalls = WrestlingPortalMatches.LoserNearFalls
		, Reversals = WrestlingPortalMatches.LoserReversals
		, InsertDate = getdate()
		, ModifiedDate = getdate()
from	#WrestlingPortalMatches WrestlingPortalMatches
join	Event
on		WrestlingPortalMatches.SystemID = Event.SystemID
		and Event.EventSystem = 'WrestlingPortal'
join	EventMatch
on		EventMatch.EventID = Event.ID
		and WrestlingPortalMatches.WeightClass = EventMatch.WeightClass
		and WrestlingPortalMatches.Division = EventMatch.Division
		and WrestlingPortalMatches.WinType = EventMatch.WinType
		and WrestlingPortalMatches.Sort = EventMatch.Sort
where	WrestlingPortalMatches.LoserWrestlerID is not null

commit

end try
begin catch

	rollback;

	throw;
end catch;

set nocount off;
