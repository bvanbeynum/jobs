select	distinct event.SystemID
from	event
where	event.eventsystem = 'Flo'
		and (event.isexcluded = 1 or event.iscomplete = 1);