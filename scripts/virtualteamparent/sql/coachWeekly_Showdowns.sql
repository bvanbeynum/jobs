;with MatchDetails as (
	select	WeekEvents.EventID
			, WeekEvents.EventName
			, EventMatch.ID as MatchID
			, EventMatch.RoundName
			, EventMatch.WeightClass
			, WinnerName = WinnerMatch.WrestlerName
			, WinnerTeam = WinnerMatch.TeamName
			, WinnerRating = WinnerRanking.Rating
			, WinnerEventWrestlerID = WinnerMatch.EventWrestlerID
			, LoserName = LoserMatch.WrestlerName
			, LoserTeam = LoserMatch.TeamName
			, LoserRating = LoserRanking.Rating
			, LoserEventWrestlerID = LoserMatch.EventWrestlerID 
			, RatingSort = WinnerRanking.Rating + LoserRanking.Rating
			, RatingDiff = abs(WinnerRanking.Rating - LoserRanking.Rating)
	from	(
			select	EventID
					, EventName
			from	#WeekEvents
			group by
					EventID
					, EventName
			) WeekEvents
	join	EventMatch
	on		WeekEvents.EventID = EventMatch.EventID
	join	EventWrestlerMatch WinnerMatch
	on		EventMatch.ID = WinnerMatch.EventMatchID
			and WinnerMatch.IsWinner = 1
	join	EventWrestlerMatch LoserMatch
	on		EventMatch.ID = LoserMatch.EventMatchID
			and LoserMatch.IsWinner = 0
	join	#EventRatings WinnerRanking
	on		WinnerMatch.EventWrestlerID = WinnerRanking.EventWrestlerID
	join	#EventRatings LoserRanking
	on		LoserMatch.EventWrestlerID = LoserRanking.EventWrestlerID
	cross apply (
			select	distinct School.SchoolName
			from	School
			join	EventSchool
			on		School.ID = EventSchool.SchoolID
			where	(EventSchool.EventSchoolName = WinnerMatch.TeamName or EventSchool.EventSchoolName = LoserMatch.TeamName)
					and School.Classification like '5a%'
			) SchoolFilter
	where	coalesce(EventMatch.Division, 'hs') like 'hs%'
			or EventMatch.Division = 'jv'
			or EventMatch.Division like '%high school%'
),
WrestlerMatchList as (
	select	WinnerEventWrestlerID as WrestlerID, MatchID, RatingDiff from MatchDetails
	union all
	select	LoserEventWrestlerID, MatchID, RatingDiff from MatchDetails
),
ToughestMatchRankings as (
	select	WrestlerID
			, MatchID
			, ToughestMatchRank = row_number() over (partition by WrestlerID order by RatingDiff asc)
	from	WrestlerMatchList
)
select	top 10 
		[Rank] = row_number() over (order by Details.RatingSort desc, Details.RatingDiff asc)
		, [Weight Class] = Details.WeightClass
		, Round = Details.RoundName
		, Winner = Details.WinnerName
		, [Winner Team] = Details.WinnerTeam
		, Loser = Details.LoserName
		, [Loser Team] = Details.LoserTeam
		, Event = Details.EventName
from	ToughestMatchRankings
join	MatchDetails as Details
on		ToughestMatchRankings.MatchID = Details.MatchID
where	ToughestMatchRankings.ToughestMatchRank = 1
group by Details.EventID
		, Details.EventName
		, Details.RoundName
		, Details.WeightClass
		, Details.WinnerName
		, Details.WinnerTeam
		, Details.WinnerRating
		, Details.LoserName
		, Details.LoserTeam
		, Details.LoserRating
		, Details.RatingSort
		, Details.RatingDiff
		, Details.MatchID
order by
		Details.RatingSort desc
		, Details.RatingDiff asc;
