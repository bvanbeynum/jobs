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
where	Event.IsExcluded = 0
		and Event.EventDate >= ?
		and (
			Event.ModifiedDate >= ?
			or exists (
				select	1
				from	EventMatch
				where	EventMatch.EventID = Event.ID
						and EventMatch.ModifiedDate >= ?
			)
			or exists (
				select	1
				from	EventMatch
				join	EventWrestlerMatch
				on		EventMatch.ID = EventWrestlerMatch.EventMatchID
				where	EventMatch.EventID = Event.ID
						and EventWrestlerMatch.ModifiedDate >= ?
			)
		)
order by
		Event.ID
offset ? rows fetch next ? rows only;
