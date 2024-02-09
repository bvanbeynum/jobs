
-- insert ELOSummary (Title) values ('Middle School Weight 8');
-- update ELOSummary set RunDate = null where id = 15;
-- delete from ELOSummary where id in (36)

select * from ELOSummary;

declare @SummaryID int;
declare @MaxIteration int;

set @SummaryID = 45;

select	@MaxIteration = max(WrestlerMatches)
from	(
		select	WrestlerMatches
				, Wrestlers = count(distinct ELORankID)
				, RunningTotal = sum(count(distinct ELORankID)) over (order by WrestlerMatches)
				, RunningPercent = (sum(cast(count(distinct ELORankID) as decimal(9,2))) over (order by WrestlerMatches) / sum(cast(count(distinct ELORankID) as decimal(9,2))) over ()) * 100
		from	(
				select	ELOMatch.ELORankID
						, WrestlerMatches = count(distinct ELOMatch.ID)
				from	ELOMatch
				join	ELORank
				on		ELOMatch.ELORankID = ELORank.ID
				where	ELORank.ELOSummaryID = @SummaryID
				group by
						ELOMatch.ELORankID
				) Accuracy
		group by
				WrestlerMatches
		) MatchAggregate
where	RunningPercent <= 90;

select	Iteration
		, Correct = sum(Correct) / count(0)
		, Incorrect = sum(Incorrect) / count(0)
		, DiffPercent = (sum(Correct) - sum(Incorrect)) / count(0)
from	(
		select	Iteration = row_number() over (partition by ELOMatch.ELORankID order by sort)
				, Correct = case when (Prediction >= .5 and IsWinner = 1) or Prediction < .5 and IsWinner = 0 then cast(1 as decimal(9,5)) else cast(0 as decimal(9,5)) end
				, Incorrect = case when (Prediction >= .5 and IsWinner = 0) or Prediction < .5 and IsWinner = 1 then cast(1 as decimal(9,5)) else cast(0 as decimal(9,5)) end
		from	ELOMatch
		join	ELORank
		on		ELOMatch.ELORankID = ELORank.ID
		where	ELORank.ELOSummaryID = @SummaryID
		) Accuracy
where	Iteration <= @MaxIteration
group by
		Iteration
order by
		Iteration;
