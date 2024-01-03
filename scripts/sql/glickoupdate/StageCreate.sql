set nocount on;

if object_id('tempdb..#TSStage') is not null
	drop table #TSStage;

create table #TSStage (
	TSWrestlerID int
	, TSMatchID int
	, Rating decimal(18,9)
	, Deviation decimal(18,9)
	, Volatility decimal(18,9)
);

set nocount off;