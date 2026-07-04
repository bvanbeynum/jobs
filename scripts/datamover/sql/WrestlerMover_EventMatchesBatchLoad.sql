select	EventID = EventMatch.EventID
		, MatchSqlID = EventMatch.ID
		, Division = EventMatch.Division
		, WeightClass = trim(replace(EventMatch.WeightClass, 'lbs', ''))
		, RoundName = EventMatch.RoundName
		, WinType = EventMatch.WinType
		, MatchSort = EventMatch.Sort
		, WinnerWrestlerSqlID = Winner.ID
		, WinnerName = WinnerMatch.WrestlerName
		, WinnerTeam = WinnerMatch.TeamName
		, WinnerRating = WinnerRating.Rating
		, WinnerDeviation = WinnerRating.Deviation
		, LoserWrestlerSqlID = Loser.ID
		, LoserName = LoserMatch.WrestlerName
		, LoserTeam = LoserMatch.TeamName
		, LoserRating = LoserRating.Rating
		, LoserDeviation = LoserRating.Deviation
from	#EventBatch
join	EventMatch
on		#EventBatch.EventID = EventMatch.EventID
join	Event
on		EventMatch.EventID = Event.ID
join	EventWrestlerMatch WinnerMatch
on		EventMatch.ID = WinnerMatch.EventMatchID
		and WinnerMatch.IsWinner = 1
join	EventWrestlerMatch LoserMatch
on		EventMatch.ID = LoserMatch.EventMatchID
		and LoserMatch.IsWinner = 0
left join
		EventWrestler Winner
on		WinnerMatch.EventWrestlerID = Winner.ID
left join
		EventWrestler Loser
on		LoserMatch.EventWrestlerID = Loser.ID
outer apply (
		select	top 1 WrestlerRating.Rating
				, WrestlerRating.Deviation
		from	WrestlerRating
		where	WinnerMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WrestlerRating.PeriodEndDate < Event.EventDate
		order by
				WrestlerRating.PeriodEndDate desc
		) WinnerRating
outer apply (
		select	top 1 WrestlerRating.Rating
				, WrestlerRating.Deviation
		from	WrestlerRating
		where	LoserMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WrestlerRating.PeriodEndDate < Event.EventDate
		order by
				WrestlerRating.PeriodEndDate desc
		) LoserRating;
