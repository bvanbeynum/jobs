set nocount on;

declare @WrestlerMatchID int;
declare @MatchID int;
declare @WrestlerID int;
declare @IsWinner bit;

set @MatchID = ?;
set @WrestlerID = ?;
set @IsWinner = ?;

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
			)
	values	(
			@MatchID
			, @WrestlerID
			, @IsWinner
			);

	select	@WrestlerMatchID = scope_identity();
end
else
begin

	update	TrackWrestlerMatch
	set		IsWinner = @IsWinner
			, ModifiedDate = getdate()
	where	ID = @WrestlerMatchID;

end

select	@WrestlerMatchID;

set nocount off;