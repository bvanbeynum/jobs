select	WrestlerID = #WrestlerStage.WrestlerID
		, MongoID = #WrestlerStage.MongoID
from	#WrestlerStage
outer apply (
		select	WrestlerID = EventWrestler.ID
		from	EventWrestler
		join	EventWrestlerMatch
		on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		where	Event.EventDate > getdate() - 720
				and EventWrestler.ID = #WrestlerStage.WrestlerID
		) ExistingWrestler
where	ExistingWrestler.WrestlerID is null