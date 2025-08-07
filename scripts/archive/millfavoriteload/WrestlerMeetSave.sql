set nocount on;

declare @FloMeetID int;
declare	@FloWrestlerID int;
declare @Division varchar(255);
declare @weightClass varchar(255);
declare @TeamName varchar(255);
declare @FloWrestlerMeetID int;
declare @IsUpdate bit;

set	@FloMeetID = ?;
set	@FloWrestlerID = ?;
set @Division = ?;
set @WeightClass = ?;
set @TeamName = ?;

select	@FloWrestlerMeetID = FloWrestlerMeet.ID
		, @IsUpdate = case 
			when coalesce(FloWrestlerMeet.Division, '') <> @Division then 1
			when coalesce(FloWrestlerMeet.weightClass, '') <> @WeightClass then 1
			when coalesce(FloWrestlerMeet.TeamName, '') <> @TeamName then 1
			else 0
			end
from	FloWrestlerMeet
where	FloWrestlerMeet.FloWrestlerID = @FloWrestlerID
		and FloWrestlerMeet.FloMeetID = @FloMeetID;

if @FloWrestlerMeetID is null
begin

	insert into FloWrestlerMeet (
			FloWrestlerID
			, FloMeetID
			, Division
			, WeightClass
			, TeamName
			)
	values	(
			@FloWrestlerID
			, @FloMeetID
			, @Division
			, @WeightClass
			, @TeamName
			);

end
else if @IsUpdate = 1
begin

	update	FloWrestlerMeet
	set		Division = @Division
			, WeightClass = @WeightClass
			, TeamName = @TeamName
	where	ID = @FloWrestlerMeetID;

end

set nocount off;