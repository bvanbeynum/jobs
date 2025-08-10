if object_id('tempdb..#EventStage') is not null
	drop table #EventStage;

create table #EventStage (
	EventID int not null primary key
);