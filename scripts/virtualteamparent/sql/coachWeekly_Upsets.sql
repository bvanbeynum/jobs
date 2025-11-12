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
			, RatingDiff = LoserRanking.Rating - WinnerRanking.Rating
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
UpsetMatches as (
	select * from MatchDetails where RatingDiff > 0
),
BiggestUpsetLosses as (
	select	*
			, BiggestUpsetRank = row_number() over (partition by LoserEventWrestlerID order by RatingDiff desc)
	from UpsetMatches
)
select	top 10 
		[Rank] = row_number() over (order by BiggestUpsetLosses.LoserRating desc)
		, [Weight Class] = BiggestUpsetLosses.WeightClass
		, Round = BiggestUpsetLosses.RoundName
		, Winner = BiggestUpsetLosses.WinnerName
		, [Winner Team] = BiggestUpsetLosses.WinnerTeam
		, Loser = BiggestUpsetLosses.LoserName
		, [Loser Team] = BiggestUpsetLosses.LoserTeam
		, Event = BiggestUpsetLosses.EventName
from	BiggestUpsetLosses
where	BiggestUpsetRank = 1
order by
		BiggestUpsetLosses.LoserRating desc;
