set nocount on;

declare @MatchID int;
declare	@UpdateType varchar(255);
declare	@UpdateMessage varchar(2000);

set	@MatchID = ?;
set	@UpdateType = ?;
set	@UpdateMessage = ?;

insert into FloMatchUpdate (
		MatchID
		, UpdateType
		, UpdateMessage
		)
values	(
		@MatchID
		, @UpdateType
		, @UpdateMessage
		);

set nocount off;