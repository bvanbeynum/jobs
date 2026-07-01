select	EventWrestlerMatch.EventWrestlerID
from	EventWrestlerMatch
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
group by
		EventWrestlerMatch.EventWrestlerID
having
		min(Event.EventDate) <= ?
		and max(Event.EventDate) >= ?;
