
if object_id('tempdb..#TSWrestler_stage') is not null
	drop table #TSWrestler_stage;

if object_id('tempdb..#TSMatch_stage') is not null
	drop table #TSMatch_stage;

create table #TSWrestler_stage (
	TSWrestlerID int
	, Rating decimal(18,9)
	, Deviation decimal(18,9)
	, Volatility decimal(18,9)
);

create table #TSMatch_stage (
	TSMatchID int
	, WinProbability decimal(18,9)
	, RatingInitial decimal(18,9)
	, DeviationInitial decimal(18,9)
	, VolatilityInitial decimal(18,9)
	, RatingUpdate decimal(18,9)
	, DeviationUpdate decimal(18,9)
	, VolatilityUpdate decimal(18,9)
);