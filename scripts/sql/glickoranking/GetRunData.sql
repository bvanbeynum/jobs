set nocount on;

declare @SummaryID int;
set @SummaryID = ?;

declare @Matches table (
	WinnerMatchID int
	, WinnerTSID int
	, LoserMatchID int
	, LoserTSID int
	, WinType varchar(255)
	, Sort int
);

insert	@Matches (
		WinnerMatchID
		, WinnerTSID
		, LoserMatchID
		, LoserTSID
		, WinType
		, Sort
		)
select	WinnerMatchID = WinnerMatch.ID
		, WinnerTSID = Winner.ID
		, LoserMatchID = LoserMatch.ID
		, LoserTSID = Loser.ID
		, Matches.WinType
		, Matches.Sort
from	(
		select	top 1000
				MatchID = TSMatch.MatchID
				, IsFlo
				, Sort = min(TSMatch.Sort)
				, WinType = case when IsFlo = 1 then FloMatch.WinType else TrackMatch.WinType end
		from	TSMatch
		join	TSWrestler
		on		TSMatch.TSWrestlerID = TSWrestler.ID
		left join
				FloMatch
		on		TSMatch.MatchID = FloMatch.ID
				and TSMatch.IsFlo = 1
		left join
				TrackMatch
		on		TSMatch.MatchID = TrackMatch.ID
				and TSMatch.IsFlo = 0
		where	TSWrestler.TSSummaryID = @SummaryID
				and TSMatch.WinProbability is null
		group by
				TSMatch.MatchID
				, IsFlo
				, FloMatch.WinType
				, TrackMatch.WinType
		order by
				min(TSMatch.Sort)
		) Matches
join	TSMatch WinnerMatch
on		Matches.MatchID = WinnerMatch.MatchID
		and Matches.IsFlo = WinnerMatch.IsFlo
		and WinnerMatch.IsWinner = 1
join	TSWrestler Winner
on		WinnerMatch.TSWrestlerID = Winner.ID
		and Winner.TSSummaryID = @SummaryID
join	TSMatch LoserMatch
on		Matches.MatchID = LoserMatch.MatchID
		and Matches.IsFlo = LoserMatch.IsFlo
		and LoserMatch.IsWinner = 0
join	TSWrestler Loser
on		LoserMatch.TSWrestlerID = Loser.ID
		and Loser.TSSummaryID = @SummaryID
order by
		Matches.Sort;

select	WrestlerID = TSWrestler.ID
		, InitialRating = TSWrestler.Rating
		, InitialDeviation = TSWrestler.Deviation
		, InitialVolatility = TSWrestler.Volatility
from	@Matches Matches
join	TSWrestler
on		TSWrestler.ID in (Matches.WinnerTSID, Matches.LoserTSID)
		and TSWrestler.TSSummaryID = @SummaryID
group by
		TSWrestler.ID
		, TSWrestler.Rating
		, TSWrestler.Deviation
		, TSWrestler.Volatility
order by
		TSWrestler.ID;

select	*
from	@Matches
order by
		Sort;

set nocount off;