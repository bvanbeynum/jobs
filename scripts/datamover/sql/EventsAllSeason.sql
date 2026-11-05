select	SqlID = Event.ID
from	Event
left join
		EventMatch
on		Event.ID = EventMatch.EventID
where	Event.IsExcluded = 0
		and event.EventSystem <> 'WrestlingPortal'
		and Event.EventDate >= ?
		and (Event.EventDate > getdate() or EventMatch.ID is not null)
group by
		Event.ID
order by
		Event.ID
