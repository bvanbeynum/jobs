set nocount on;

declare @WrestlerMatchID int;
declare @MatchID int;
declare @WrestlerID int;
declare @IsWinner bit;
declare @Team varchar(255);

set @MatchID = ?;
set @WrestlerID = ?;
set @IsWinner = ?;
set @Team = ?;

select	@WrestlerMatchID = TrackWrestlerMatch.ID
from	TrackWrestlerMatch
where	TrackMatchID = @MatchID
		and TrackWrestlerID = @WrestlerID;

if @WrestlerMatchID is null
begin

	insert	TrackWrestlerMatch (
			TrackMatchID
			, TrackWrestlerID
			, IsWinner
			, Team
			)
	values	(
			@MatchID
			, @WrestlerID
			, @IsWinner
			, @Team
			);

	select	@WrestlerMatchID = scope_identity();
end
else
begin

	update	TrackWrestlerMatch
	set		IsWinner = @IsWinner
			, Team = @Team
			, ModifiedDate = getdate()
	where	ID = @WrestlerMatchID;

end

select	@WrestlerMatchID;

set nocount off;