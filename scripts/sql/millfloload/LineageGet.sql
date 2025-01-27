set nocount on;

declare @LookupWrestler int;
set @LookupWrestler = ?;

select	Packet = '[' + string_agg('[' + WrestlerLineage.Packet + ']', ',') + ']'
from	WrestlerLineage with (nolock)
where	WrestlerLineage.InitialFloID = @LookupWrestler
		and WrestlerLineage.Wrestler2Team = 'fort mill';

set nocount off;