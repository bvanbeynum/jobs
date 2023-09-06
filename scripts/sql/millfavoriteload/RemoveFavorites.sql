set nocount on;

declare @IDs varchar(max);
set @IDs = ?;

update	FloMeet
set		IsFavorite = 0
where	@IDs not like '%|' + cast(FloMeet.ID as varchar(255)) + '|%';

set nocount off;