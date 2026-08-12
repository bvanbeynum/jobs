if object_id('tempdb..#WrestlerRatingsBatch') is not null
	drop table #WrestlerRatingsBatch

create table #WrestlerRatingsBatch (
	WrestlerID int
);
