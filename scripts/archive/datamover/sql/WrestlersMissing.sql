select	distinct WrestlerID
from	#Mill
where	WrestlerID not in (select ID from FloWrestler)
order by
		WrestlerID;