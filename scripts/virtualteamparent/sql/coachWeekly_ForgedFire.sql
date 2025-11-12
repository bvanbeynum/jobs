with OpponentSkill as (
select	Division = case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
		, Wrestler = EventWrestler.WrestlerName
		, IsWin = case when EventWrestlerMatch.IsWinner = 1 then 'Beat ' else 'Lost to ' end
		, Opponent = OpponentMatch.WrestlerName
		, OpponentTeam = OpponentMatch.TeamName
		, OpponentRating = OpponentRating.Rating
		, OpponentRank = rank() over (
			partition by EventWrestler.WrestlerName
			order by OpponentRating.Rating desc
			)
		, MaxRating = max(OpponentRating.Rating) over (partition by EventWrestler.id)
		, OverRated = case when OpponentRating.Rating > percentile_cont(0.8) within group (order by Rating) over (partition by EventWrestler.id) then 1 else 0 end
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestlerMatch OpponentMatch
on		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and EventWrestlerMatch.EventWrestlerID <> OpponentMatch.EventWrestlerID
join	WrestlerRating OpponentRating
on		OpponentMatch.EventWrestlerID = OpponentRating.EventWrestlerID
		and WeekEvents.EventDate between dateadd(day, -6, OpponentRating.PeriodEndDate) and OpponentRating.PeriodEndDate
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
where	WeekEvents.SchoolID = 71 -- Fort Mill
)
select	Division
		, Rank
		, Wrestler
		, Opponents
from	(
		select	Division
				, Rank = rank() over (partition by Division order by sum(OverRated) desc, max(MaxRating) desc)
				, Wrestler
				, Opponents = string_agg('* ' + IsWin + ' ' + Opponent + ' (' + OpponentTeam + ')', '\n') within group (order by OpponentRating desc)
		from	OpponentSkill
		where	OpponentRank <= 2
		group by
				Division
				, Wrestler
		) as RankedOpponents
where	Rank <= 5
order by
		Division desc
		, Rank
