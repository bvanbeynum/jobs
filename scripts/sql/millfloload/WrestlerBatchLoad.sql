set nocount on;

declare @BatchSize int;

set @BatchSize = ?;

insert	#WrestlerLoadBatch (
		WrestlerID
		, FirstName
		, LastName
		, gRating
		, gDeviation
		, Teams
		)
select	WrestlerID
		, FirstName
		, LastName
		, gRating
		, gDeviation
		, Teams
from	(
		select	Wrestlers.WrestlerID
				, Wrestlers.FirstName
				, Wrestlers.LastName
				, Wrestlers.gRating
				, Wrestlers.gDeviation
				, Wrestlers.Teams
				, RowFilter = row_number() over (order by Wrestlers.LastModified desc)
		from	#Wrestlers Wrestlers
		) Batch
where	RowFilter <= @BatchSize;

set nocount off;