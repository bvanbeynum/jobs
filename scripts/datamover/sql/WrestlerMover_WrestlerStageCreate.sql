if object_id('tempdb..#WrestlerStage') is not null
	drop table #WrestlerStage

create table #WrestlerStage (
	WrestlerID int
	, MongoID varchar(max)
)