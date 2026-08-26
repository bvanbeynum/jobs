set nocount on;

declare @StartDate int;
declare @TimespanDays int;
declare @Offset int;
declare @BatchSize int;

set @StartDate = ?;
set @TimespanDays = ?;
set @Offset = ?;
set @BatchSize = ?;

select	SqlID = Event.ID
		, EventSystem = Event.EventSystem
		, SystemID = Event.SystemID
		, EventType = Event.EventType
		, EventName = Event.EventName
		, EventDate = Event.EventDate
		, EndDate = Event.EndDate
		, Location = Event.EventAddress
		, EventState = Event.EventState
		, Created = Event.InsertDate
		, Modified = Event.ModifiedDate
from	Event
where	event.EventSystem <> 'WrestlingPortal'
		and Event.IsExcluded = 0
		and Event.EventDate >= dateadd(day, @StartDate, getdate())
		and (
			Event.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
			or exists (
				select	1
				from	EventMatch
				where	EventMatch.EventID = Event.ID
						and EventMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
			)
			or exists (
				select	1
				from	EventMatch
				join	EventWrestlerMatch
				on		EventMatch.ID = EventWrestlerMatch.EventMatchID
				where	EventMatch.EventID = Event.ID
						and EventWrestlerMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
			)
		)
order by
		Event.ID
offset @Offset rows fetch next @BatchSize rows only;

set nocount off;
