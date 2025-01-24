set nocount on;

select	distinct WrestlerLineage.WrestlerID
		, WrestlerLineage.FloWrestlerID
from	WrestlerLineage
where	WrestlerLineage.FloWrestlerID is not null
		and WrestlerLineage.ModifiedDate > getdate() - 7
order by
		WrestlerLineage.FloWrestlerID;

set nocount off;