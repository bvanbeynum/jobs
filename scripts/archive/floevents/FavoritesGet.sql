select	EventID = event.id
		, event.systemid
		, event.eventname
		, event.eventaddress
		, event.eventstate
		, eventdate = convert(varchar, event.eventdate, 21)
		, enddate = convert(varchar, event.enddate, 21)
from	event
where	event.eventsystem = 'Flo'
		and event.iscomplete = 0;