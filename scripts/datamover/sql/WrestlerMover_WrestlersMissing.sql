select	WrestlerID = #WrestlerStage.WrestlerID
		, MongoID = #WrestlerStage.MongoID
from	#WrestlerStage
left join
		EventWrestler
on
		#WrestlerStage.WrestlerID = EventWrestler.ID
where	EventWrestler.ID is null
