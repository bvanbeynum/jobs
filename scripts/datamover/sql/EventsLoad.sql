set nocount on;

declare @StartDate date;
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
left join
		EventMatch
on		Event.ID = EventMatch.EventID
where	event.EventSystem <> 'WrestlingPortal'
		and Event.IsExcluded = 0
		and Event.EventDate >= @StartDate
		and (
			Event.ModifiedDate >= dateadd(day, @TimespanDays, getdate()) -- Event was modified since the date
			or exists (
				select	1
				from	EventMatch
				where	EventMatch.EventID = Event.ID
						and EventMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate()) -- A match was modified since the date
			)
			or exists (
				select	1
				from	EventMatch
				join	EventWrestlerMatch
				on		EventMatch.ID = EventWrestlerMatch.EventMatchID
				where	EventMatch.EventID = Event.ID
						and EventWrestlerMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate()) -- A wrestler match was modified since the date
			)
		)
		and (Event.EventDate > getdate() or EventMatch.ID is not null)
group by
		Event.ID
		, Event.EventSystem
		, Event.SystemID
		, Event.EventType
		, Event.EventName
		, Event.EventDate
		, Event.EndDate
		, Event.EventAddress
		, Event.EventState
		, Event.InsertDate
		, Event.ModifiedDate
order by
		Event.ID
offset @Offset rows fetch next @BatchSize rows only;

set nocount off;
