with WrestlerEvent as (
	select	TSWrestlerID = TSWrestler.ID
			, EventNumber = row_number() over (partition by TSWrestler.ID order by TSMatch.EventDate)
			, TSMatch.EventID
			, TSMatch.IsFlo
			, TSWrestler.TSSummaryID
	from	TSMatch
	join	TSWrestler
	on		TSMatch.TSWrestlerID = TSWrestler.ID
	where	TSWrestler.TSSummaryID = 51
			and TSMatch.RatingUpdate is not null
	group by
			TSWrestler.ID
			, TSMatch.EventDate
			, TSMatch.EventID
			, TSMatch.IsFlo
			, TSWrestler.TSSummaryID
		),
WrestlerMatch as (
	select	TSWrestlerID = TSWrestler.ID
			, TSMatch.IsFlo
			, TSMatch.EventID
			, MatchNumber = row_number() over (partition by TSWrestler.ID order by TSMatch.Sort)
			, TSMatch.MatchID
			, TSMatch.RatingInitial
			, TSMatch.DeviationInitial
			, TSMatch.IsWinner
	from	TSMatch
	join	TSWrestler
	on		TSMatch.TSWrestlerID = TSWrestler.ID
	where	TSWrestler.TSSummaryID = 51
			and TSMatch.RatingUpdate is not null
)
select	WrestlerEvent.TSWrestlerID
		, WrestlerEvent.EventNumber
		, WrestlerMatch.MatchNumber
		, WrestlerMatch.IsWinner
		, Probability = dbo.G2Predict(WrestlerMatch.RatingInitial, WrestlerMatch.DeviationInitial, Opponent.Rating, Opponent.Deviation)
into	#MatchData
from	WrestlerEvent
join	WrestlerMatch
on		WrestlerEvent.TSWrestlerID = WrestlerMatch.TSWrestlerID
		and WrestlerEvent.EventID = WrestlerMatch.EventID
		and WrestlerEvent.IsFlo = WrestlerMatch.IsFlo
cross apply (
		select	Rating = OpponentMatch.RatingInitial
				, Deviation = OpponentMatch.DeviationInitial
		from	WrestlerMatch OpponentMatch
		join	WrestlerEvent OpponentEvent
		on		OpponentMatch.TSWrestlerID = OpponentEvent.TSWrestlerID
				and OpponentMatch.EventID = OpponentEvent.EventID
				and OpponentMatch.IsFlo = OpponentEvent.IsFlo
		where	WrestlerMatch.MatchID = OpponentMatch.MatchID
				and WrestlerMatch.IsFlo = OpponentMatch.IsFlo
				and WrestlerMatch.TSWrestlerID <> OpponentMatch.TSWrestlerID
				and OpponentEvent.EventNumber <> 1
		) Opponent
where	WrestlerEvent.EventNumber <> 1

select top 100 * from #MatchData

select	EventNumber
		, AverageDiff = avg(Diff)
		, Wrestlers = count(distinct TSWrestlerID)
		, RunningTotal = sum(count(distinct TSWrestlerID)) over (order by EventNumber)
		, RunningPercent = (sum(cast(count(distinct TSWrestlerID) as decimal(9,2))) over (order by EventNumber) / sum(cast(count(distinct TSWrestlerID) as decimal(9,2))) over ()) * 100
from	(
		select	TSWrestlerID
				, EventNumber
				, AvgCorrect = avg(case when (IsWinner = 1 and Probability > .5) or (IsWinner = 0 and Probability < .5) then 1.0 else 0.0 end)
				, AvgIncorrect = avg(case when (IsWinner = 0 and Probability > .5) or (IsWinner = 1 and Probability < .5) then 1.0 else 0.0 end)
				, Diff = avg(case when (IsWinner = 1 and Probability > .5) or (IsWinner = 0 and Probability < .5) then 1.0 else 0.0 end) - avg(case when (IsWinner = 0 and Probability > .5) or (IsWinner = 1 and Probability < .5) then 1.0 else 0.0 end)
		from	#MatchData
		where	Probability <> .5
		group by
				TSWrestlerID
				, EventNumber
		) Accuracy
group by
		EventNumber
order by
		EventNumber
