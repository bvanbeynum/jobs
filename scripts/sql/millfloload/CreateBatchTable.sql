set nocount on;

if object_id('tempdb..#WrestlerLoadBatch') is not null
	drop table #WrestlerLoadBatch;

create table #WrestlerLoadBatch (
	WrestlerID int
	, FirstName varchar(255)
	, LastName varchar(255)
	, gRating decimal(18,9)
	, gDeviation decimal(18,9)
	, Teams varchar(max)
	, LastModified datetime
	, IsLineageModified int
);

set nocount off;