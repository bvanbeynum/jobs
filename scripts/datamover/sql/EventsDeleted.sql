select	distinct EventID
from	#EventStage
where	EventID not in (select ID from Event where 1 = 0)
order by
		EventID;