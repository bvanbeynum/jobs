select	SqlID = Event.ID
from	Event
where	Event.IsExcluded = 0
		and Event.EventDate >= ?
order by
		Event.ID
