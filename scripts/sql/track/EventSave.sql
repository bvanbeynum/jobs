set nocount on;

declare @TrackEventID int
declare @EventID int;
declare @EventType varchar(255);
declare @EventName varchar(255);
declare @EventDate date;
declare @EndDate date;
declare @SourceDate varchar(255);
declare @EventAddress varchar(255);
declare @EventState varchar(255);
declare @IsComplete bit;

set @EventID = ?;
set @EventType = ?;
set @EventName = ?;
set @EventDate = ?;
set @EndDate = ?;
set @SourceDate = ?;
set @EventAddress = ?;
set @EventState = ?;
set	@IsComplete = ?;

select	@TrackEventID = TrackEvent.ID
from	TrackEvent
where	EventID = @EventID;

if @TrackEventID is null
begin

	insert	TrackEvent (
			EventID
			, EventType
			, EventName
			, EventDate
			, EndDate
			, SourceDate
			, EventAddress
			, EventState
			, IsComplete
			, InsertDate
			, ModifiedDate
			)
	values	(
			@EventID
			, @EventType
			, @EventName
			, @EventDate
			, @EndDate
			, @SourceDate
			, @EventAddress
			, @EventState
			, @IsComplete
			, getdate()
			, getdate()
			);

	select	@TrackEventID = scope_identity();
end
else
begin

	update	TrackEvent
	set		EventType = coalesce(@EventType, EventType)
			, EventName = coalesce(@EventName, EventName)
			, EventDate = coalesce(@EventDate, EventDate)
			, EndDate = coalesce(@EndDate, EndDate)
			, SourceDate = coalesce(@SourceDate, SourceDate)
			, EventAddress = coalesce(@EventAddress, EventAddress)
			, EventState = coalesce(@EventState, EventState)
			, IsComplete = coalesce(@IsComplete, IsComplete)
			, ModifiedDate = getdate()
	where	ID = @TrackEventID;

end

select	@TrackEventID;

set nocount off;