set nocount on;

declare @WrestlerMatchID int;
declare @MatchID int;
declare @WrestlerID int;
declare @IsWinner bit;
declare @Team varchar(255);
declare @WrestlerName varchar(255)

set @MatchID = ?;
set @WrestlerID = ?;
set @IsWinner = ?;
set @Team = ?;
set @WrestlerName = ?;

select	@WrestlerMatchID = EventWrestlerMatch.ID
from	EventWrestlerMatch
where	EventMatchID = @MatchID
		and EventWrestlerID = @WrestlerID;

if @WrestlerMatchID is null
begin

	insert	EventWrestlerMatch (
			EventMatchID
			, EventWrestlerID
			, IsWinner
			, WrestlerName
			, TeamName
			)
	values	(
			@MatchID
			, @WrestlerID
			, @IsWinner
			, @WrestlerName
			, @Team
			);

	select	@WrestlerMatchID = scope_identity();
end
else
begin

	update	EventWrestlerMatch
	set		IsWinner = @IsWinner
			, WrestlerName = @WrestlerName
			, TeamName = @Team
			, ModifiedDate = getdate()
	where	ID = @WrestlerMatchID;

end

select	@WrestlerMatchID;

set nocount off;