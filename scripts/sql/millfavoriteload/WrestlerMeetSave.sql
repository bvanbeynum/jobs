set nocount on;

declare @FloMeetID int;
declare	@FloWrestlerID int;
declare @FloWrestlerMeetID int;

set	@FloMeetID = ?;
set	@FloWrestlerID = ?;

select	@FloWrestlerMeetID = FloWrestlerMeet.ID
from	FloWrestlerMeet
where	FloWrestlerMeet.FloWrestlerID = @FloWrestlerID
		and FloWrestlerMeet.FloMeetID = @FloMeetID;

if @FloWrestlerMeetID is null
begin

	insert into FloWrestlerMeet (
			FloWrestlerID
			, FloMeetID
			)
	values	(
			@FloWrestlerID
			, @FloMeetID
			);

end

set nocount off;