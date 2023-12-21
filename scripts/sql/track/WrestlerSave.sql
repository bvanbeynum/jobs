set nocount on;

declare @WrestlerID int;
declare @WrestlerName varchar(255);
declare @TeamName varchar(255);

set @WrestlerName = ?;
set @TeamName = ?;

select	@WrestlerID = TrackWrestler.ID
from	TrackWrestler
where	WrestlerName = @WrestlerName
		and TeamName = @TeamName;

if @WrestlerID is null
begin

	insert	TrackWrestler (
			WrestlerName
			, TeamName
			)
	values	(
			@WrestlerName
			, @TeamName
			);

	select	@WrestlerID = scope_identity();
end

select	@WrestlerID;

set nocount off;