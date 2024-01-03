set nocount on;

declare	@FirstDate date;
declare @EventYear int;
declare	@EventWeek int;
declare @SummaryID int;

declare @Wrestler table (
	TSWrestlerID int
	, Rating decimal(18,9)
	, Deviation decimal(18,9)
	, Volatility decimal(18,9)
)

set	@SummaryID = 51;

select	@FirstDate = min(TSMatch.EventDate)
		, @EventYear = datepart(yyyy, min(TSMatch.EventDate))
		, @EventWeek = datepart(wk, min(TSMatch.EventDate))
from	TSMatch
join	TSWrestler
on		TSMatch.TSWrestlerID = TSWrestler.ID
cross apply (
		select	ID = cast(FilterMatch.MatchID as varchar(max)) + '.' + cast(FilterMatch.IsFlo as varchar(max))
		from	TSMatch FilterMatch
		join	TSWrestler FilterWrestler
		on		FilterMatch.TSWrestlerID = FilterWrestler.ID
		where	FilterWrestler.TSSummaryID = TSWrestler.TSSummaryID
				and TSMatch.IsFlo = FilterMatch.IsFlo
				and TSMatch.MatchID = FilterMatch.MatchID
		group by
				FilterMatch.MatchID
				, FilterMatch.IsFlo
		having	count(distinct FilterMatch.ID) > 1
		) FilterMatches
where	TSWrestler.TSSummaryID = @SummaryID
		and TSMatch.RatingUpdate is null;

insert	@Wrestler (
		TSWrestlerID
		, Rating
		, Deviation
		, Volatility
		)
select	TSWrestlerID = TSWrestler.ID
		, TSWrestler.Rating
		, TSWrestler.Deviation
		, TSWrestler.Volatility
from	TSMatch
join	TSWrestler
on		TSMatch.TSWrestlerID = TSWrestler.ID
where	TSWrestler.TSSummaryID = @SummaryID
		and TSMatch.EventDate > dateadd(d, -365, @FirstDate)
		and (
			TSMatch.EventDate < @FirstDate
			or (
				datepart(yyyy, TSMatch.EventDate) = @EventYear 
				and datepart(wk, TSMatch.EventDate) = @EventWeek
			)
		)
group by
		TSWrestler.ID
		, TSWrestler.Rating
		, TSWrestler.Deviation
		, TSWrestler.Volatility;

update	TSMatch
set		RatingInitial = UpdateData.Rating
		, DeviationInitial = UpdateData.Deviation
		, VolatilityInitial = UpdateData.Volatility
from	TSMatch
join	(
		select	TSMatchID = TSMatch.ID
				, Wrestler.Rating
				, Wrestler.Deviation
				, Wrestler.Volatility
		from	@Wrestler Wrestler
		join	TSMatch
		on		Wrestler.TSWrestlerID = TSMatch.TSWrestlerID
		where	TSMatch.RatingUpdate is null
				and datepart(yyyy, TSMatch.EventDate) = @EventYear
				and datepart(wk, TSMatch.EventDate) = @EventWeek
		) UpdateData
on		TSMatch.ID = UpdateData.TSMatchID;

select	Wrestler.TSWrestlerID
		, Wrestler.Rating
		, Wrestler.Deviation
		, Wrestler.Volatility
		, TSMatchID = TSMatch.ID
		, MatchResult = case when coalesce(FloMatch.WinType, TrackMatch.WinType) = 'f' then TSMatch.IsWinner * 1.2 else TSMatch.IsWinner end
		, OpponentRating = Opponent.Rating
		, OpponentDeviation = Opponent.Deviation
from	@Wrestler Wrestler
left join
		TSMatch
on		Wrestler.TSWrestlerID = TSMatch.TSWrestlerID
		and TSMatch.RatingUpdate is null
		and datepart(yyyy, TSMatch.EventDate) = @EventYear
		and datepart(wk, TSMatch.EventDate) = @EventWeek
left join
		TSMatch OpponentMatch
on		TSMatch.MatchID = OpponentMatch.MatchID
		and TSMatch.IsFlo = OpponentMatch.IsFlo
		and TSMatch.TSWrestlerID <> OpponentMatch.TSWrestlerID
left join
		TSWrestler Opponent
on		OpponentMatch.TSWrestlerID = Opponent.ID
		and Opponent.TSSummaryID = @SummaryID
left join
		FloMatch
on		TSMatch.MatchID = FloMatch.ID
		and TSMatch.IsFlo = 1
left join
		TrackMatch
on		TSMatch.MatchID = TrackMatch.ID
		and TSMatch.IsFlo = 0
where	TSMatch.ID is null
		or Opponent.ID is not null
order by
		Wrestler.TSWrestlerID
		, TSMatch.Sort;

set nocount off;
