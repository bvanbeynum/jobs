select	distinct EventID
from	#EventStage
where	EventID not in (select ID from Event)
order by
		EventID;