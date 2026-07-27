set nocount on;

declare @TimespanEventDays int;
declare @TimespanDays int;

set @TimespanEventDays = -720 -- ?;

select	sourceid = SourceMatch.EventWrestlerID
		, targetid = TargetMatch.EventWrestlerID
		, matchid = EventMatch.ID
		, EventDate = cast(Event.EventDate as varchar(255))
		, SourceMatch.IsWinner
		, EventMatch.WinType
from	Event
join	EventMatch
on		Event.ID = EventMatch.EventID
join	EventWrestlerMatch SourceMatch
on		EventMatch.ID = SourceMatch.EventMatchID
join	EventWrestlerMatch TargetMatch
on		SourceMatch.EventMatchID = TargetMatch.EventMatchID
		and TargetMatch.EventWrestlerID <> SourceMatch.EventWrestlerID
where	Event.EventDate > dateadd(day, @TimespanEventDays, getdate())

set nocount off;
