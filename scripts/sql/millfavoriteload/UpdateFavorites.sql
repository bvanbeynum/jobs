set nocount on;

declare @IDs varchar(max);
set @IDs = ?;

update	FloMeet
set		IsFavorite = 1
where	@IDs like '%|' + cast(FloMeet.ID as varchar(255)) + '|%';

set nocount off;