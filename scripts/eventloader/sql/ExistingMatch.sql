set nocount on;

declare @EventID int;
declare @Division varchar(255);
declare @WeightClass varchar(255);
declare @RoundName varchar(255);
declare @WinType varchar(255);

declare @Wrestler1 int;
declare @Wrestler2 int;

set @EventID = ?;
set @Division = ?;
set @WeightClass = ?;
set @RoundName = ?;
set @WinType = ?;

set @Wrestler1 = ?;
set @Wrestler2 = ?;

select	Matches = count(0)
from	EventMatch
join	EventWrestlerMatch Wrestler1
on		EventMatch.ID = Wrestler1.EventMatchID
		and Wrestler1.EventWrestlerID = @Wrestler1
join	EventWrestlerMatch Wrestler2
on		EventMatch.ID = Wrestler2.EventMatchID
		and Wrestler2.EventWrestlerID = @Wrestler2
where	EventMatch.EventID = @EventID
		and coalesce(EventMatch.Division, '') = coalesce(@Division, '')
		and coalesce(EventMatch.WeightClass, '') = coalesce(@WeightClass, '')
		and coalesce(EventMatch.RoundName, '') = coalesce(@RoundName, '')
		and coalesce(EventMatch.WinType, '') = coalesce(@WinType, '');

set nocount off;