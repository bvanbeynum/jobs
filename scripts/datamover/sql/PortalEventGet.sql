select	distinct 
		SystemID = Event.SystemID
		, EventID = Event.ID
from	Event
where	Event.EventSystem = 'WrestlingPortal'
		and Event.SystemID in (select distinct SystemID from #WrestlingPortalMatches)
