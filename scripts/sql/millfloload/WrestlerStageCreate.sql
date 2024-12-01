if object_id('tempdb..#Mill') is not null
	drop table #Mill;

create table #Mill (
	WrestlerID int not null primary key
);