
-- insert TSSummary (Title) values ('Migration Test');
-- update TSSummary set RunDate = null where id = 19;
-- delete from TSSummary where id in (21,22,26,36,37,38)

select * from TSSummary;

declare @SummaryID int;
declare @MaxIteration int;

set @SummaryID = 39;

select	@MaxIteration = max(WrestlerMatches)
from	(
		select	WrestlerMatches
				, Wrestlers = count(distinct TSWrestlerID)
				, RunningTotal = sum(count(distinct TSWrestlerID)) over (order by WrestlerMatches)
				, RunningPercent = (sum(cast(count(distinct TSWrestlerID) as decimal(9,2))) over (order by WrestlerMatches) / sum(cast(count(distinct TSWrestlerID) as decimal(9,2))) over ()) * 100
		from	(
				select	TSMatch.TSWrestlerID
						, WrestlerMatches = count(distinct TSMatch.ID)
				from	TSMatch
				join	TSWrestler
				on		TSMatch.TSWrestlerID = TSWrestler.ID
				where	TSWrestler.TSSummaryID = @SummaryID
				group by
						TSMatch.TSWrestlerID
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
		select	Iteration = row_number() over (partition by TSMatch.TSWrestlerID order by sort)
				, Correct = case when (WinProbability >= .5 and IsWinner = 1) or WinProbability < .5 and IsWinner = 0 then cast(1 as decimal(9,5)) else cast(0 as decimal(9,5)) end
				, Incorrect = case when (WinProbability >= .5 and IsWinner = 0) or WinProbability < .5 and IsWinner = 1 then cast(1 as decimal(9,5)) else cast(0 as decimal(9,5)) end
		from	TSMatch
		join	TSWrestler
		on		TSMatch.TSWrestlerID = TSWrestler.ID
		where	TSWrestler.TSSummaryID = @SummaryID
		) Accuracy
where	Iteration <= @MaxIteration
group by
		Iteration
order by
		Iteration;

/*

update	FloWrestler
set		GRating = TSWrestler.Rating
		, GDeviation = TSWrestler.Deviation
from	FloWrestler
join	TSWrestler
on		FloWrestler.ID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = 39

*/