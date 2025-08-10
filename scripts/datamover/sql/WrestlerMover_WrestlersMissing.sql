select	WrestlerID = Wrestler.ID
from	Wrestler
left join	#WrestlerStage
on
		#WrestlerStage.WrestlerID = Wrestler.ID
where	#WrestlerStage.WrestlerID is null
