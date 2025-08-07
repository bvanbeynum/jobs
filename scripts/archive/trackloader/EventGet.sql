select	Event.ID
		, Event.IsComplete
from	Event
where	Event.SystemID = ?;