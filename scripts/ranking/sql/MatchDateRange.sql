select	MinDate = min(Event.EventDate)
		, MaxDate = max(Event.EventDate)
from	Event
join	EventMatch
on		Event.ID = EventMatch.EventID
where	Event.EventDate < getdate()
		and event.EventDate > '2021-09-01';
