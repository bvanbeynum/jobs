if object_id('tempdb..#EventBatch') is not null
	drop table #EventBatch

create table #EventBatch (
		EventID int primary key
);
