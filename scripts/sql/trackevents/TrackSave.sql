declare @TrackEventID int;
declare @EventID varchar(255);
declare @EventName varchar(255);
declare @EventDate date;
declare @EndDate date;
declare @SourceDate varchar(255);
declare @EventAddress varchar(255);
declare @EventState varchar(255);

set @EventID = ?;
set @EventName = ?;
set @EventDate = ?;
set @EndDate = ?;
set @SourceDate = ?;
set @EventAddress = ?;
set @EventState = ?;

select	@TrackEventID = TrackEvent.ID
from	TrackEvent
where	EventID = @EventID;

if @TrackEventID is null
begin

	insert	TrackEvent (
				EventID
				, EventName
				, EventDate
				, EndDate
				, SourceDate
				, EventAddress
				, EventState
				, ModifiedDate
			)
	values	(
				@EventID
				, @EventName
				, @EventDate
				, @EndDate
				, @SourceDate
				, @EventAddress
				, @EventState
				, getdate()
			);
	
	select	@TrackEventID = scope_identity();

end
else
begin

	update	TrackEvent
	set		EventName = @EventName
			, EventDate = @EventDate
			, EndDate = @EndDate
			, SourceDate = @SourceDate
			, EventAddress = @EventAddress
			, EventState = @EventState
			, ModifiedDate = getdate()
	where	TrackEvent.ID = @TrackEventID;

end;
