set nocount on;

declare @EventID int
declare @SystemID varchar(255);
declare @EventName varchar(255);
declare @EventDate date;
declare @EndDate date;
declare @EventAddress varchar(255);
declare @EventState varchar(255);
declare @IsComplete bit;
declare @IsExcluded bit;

set @SystemID = ?;
set @EventName = ?;
set @EventDate = ?;
set @EndDate = ?;
set @EventAddress = ?;
set @EventState = ?;
set	@IsComplete = ?;
set	@IsExcluded = ?;

select	@EventID = Event.ID
from	Event
where	SystemID = @SystemID;

if @EventID is null
begin

	insert	Event (
			EventSystem
			, SystemID
			, EventType
			, EventName
			, EventDate
			, EndDate
			, EventAddress
			, EventState
			, IsComplete
			, IsExcluded
			, InsertDate
			, ModifiedDate
			)
	values	(
			'Flo'
			, @SystemID
			, null
			, @EventName
			, @EventDate
			, @EndDate
			, @EventAddress
			, @EventState
			, @IsComplete
			, @IsExcluded
			, getdate()
			, getdate()
			);

	select	@EventID = scope_identity();
end
else
begin

	update	Event
	set		EventType = null
			, EventName = coalesce(@EventName, EventName)
			, EventDate = coalesce(@EventDate, EventDate)
			, EndDate = coalesce(@EndDate, EndDate)
			, EventAddress = coalesce(@EventAddress, EventAddress)
			, EventState = coalesce(@EventState, EventState)
			, IsComplete = coalesce(@IsComplete, IsComplete)
			, IsExcluded = coalesce(@IsExcluded, IsExcluded)
			, ModifiedDate = getdate()
	where	ID = @EventID;

end

select	@EventID;

set nocount off;