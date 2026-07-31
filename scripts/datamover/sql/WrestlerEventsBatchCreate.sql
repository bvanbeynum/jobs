if object_id('tempdb..#WrestlerEventsBatch') is not null
	drop table #WrestlerEventsBatch

create table #WrestlerEventsBatch (
	WrestlerID int
);
