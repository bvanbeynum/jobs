set nocount on;

select	distinct WrestlerLineage.InitialFloID
from	WrestlerLineage with (nolock)
where	WrestlerLineage.ModifiedDate > getdate() - 7
order by
		WrestlerLineage.InitialFloID;

set nocount off;