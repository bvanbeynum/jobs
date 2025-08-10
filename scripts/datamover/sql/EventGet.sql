declare @Days int;

set @Days = ?;

select	EventID = Event.ID
		, EventSystem = Event.EventSystem
		, SystemID = Event.SystemID
		, EventType = Event.EventType
		, EventName = Event.EventName
		, EventDate = Event.EventDate
		, EndDate = Event.EndDate
		, EventAddress = Event.EventAddress
		, EventState = Event.EventState
from	Event
where	Event.IsExcluded = 0
		and Event.ModifiedDate > dateadd(day, @Days * -1, cast(getdate() as date))
order by
		Event.ID
