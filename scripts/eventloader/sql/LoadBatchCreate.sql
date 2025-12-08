if object_id('tempdb..#MatchStage') is not null
	drop table #MatchStage;

create table #MatchStage (
	SystemID varchar(255)
	, EventID int
	, DivisionName varchar(255)
	, WeightClassName varchar(255)
	, MatchRound varchar(255)
	, WinType varchar(255)
	, Wrestler1SystemID varchar(255)
	, Wrestler1Name varchar(255)
	, Wrestler1Team varchar(255)
	, Wrestler1IsWinner bit
	, Wrestler2SystemID varchar(255)
	, Wrestler2Name varchar(255)
	, Wrestler2Team varchar(255)
	, Wrestler2IsWinner bit
	, Sort int
);
