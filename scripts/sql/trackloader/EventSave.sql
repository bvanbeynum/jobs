set nocount on;

declare @EventID int
declare @SystemID varchar(255);
declare @EventType varchar(255);
declare @EventName varchar(255);
declare @EventDate date;
declare @EndDate date;
declare @EventAddress varchar(255);
declare @EventState varchar(255);
declare @IsComplete bit;

set @SystemID = ?;
set @EventType = ?;
set @EventName = ?;
set @EventDate = ?;
set @EndDate = ?;
set @EventAddress = ?;
set @EventState = ?;
set	@IsComplete = ?;

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
			, InsertDate
			, ModifiedDate
			)
	values	(
			'Track'
			, @SystemID
			, @EventType
			, @EventName
			, @EventDate
			, @EndDate
			, @EventAddress
			, @EventState
			, @IsComplete
			, getdate()
			, getdate()
			);

	select	@EventID = scope_identity();
end
else
begin

	update	Event
	set		EventType = coalesce(@EventType, EventType)
			, EventName = coalesce(@EventName, EventName)
			, EventDate = coalesce(@EventDate, EventDate)
			, EndDate = coalesce(@EndDate, EndDate)
			, EventAddress = coalesce(@EventAddress, EventAddress)
			, EventState = coalesce(@EventState, EventState)
			, IsComplete = coalesce(@IsComplete, IsComplete)
			, ModifiedDate = getdate()
	where	ID = @EventID;

end

select	@EventID;

set nocount off;