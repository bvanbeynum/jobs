if object_id('tempdb..#WrestlerBatch') is not null
	drop table #WrestlerBatch

create table #WrestlerBatch (
	WrestlerID int
);
