with WrestlerImprovement as (
select	Division = case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
		, Rank = rank() over (
			partition by case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
			order by WrestlerRating.Rating - PreviousRating.PreviousRating desc
			)
		, Wrestler = EventWrestler.WrestlerName
		, [Key Wins] = replace(trim(string_agg(
			case when EventWrestlerMatch.IsWinner = 1 then
				concat(
					'- Defeated '
					, OpponentMatch.WrestlerName
					, ' ('
					, OpponentMatch.TeamName
					, ')'
				)
			else ''
			end
			, '\n') within group (order by EventMatch.ID)), '\n\n', '\n')
		, Improvement = WrestlerRating.Rating - PreviousRating.PreviousRating
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
join	WrestlerRating
on		EventWrestlerMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
		and WeekEvents.EventDate between dateadd(day, -6, WrestlerRating.PeriodEndDate) and WrestlerRating.PeriodEndDate
join	EventWrestlerMatch OpponentMatch
on		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and EventWrestlerMatch.EventWrestlerID <> OpponentMatch.EventWrestlerID
cross apply (
		select	top 1
				PreviousRating = WrestlerPreviousRating.Rating
		from	WrestlerRating WrestlerPreviousRating
		where	WrestlerPreviousRating.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WrestlerPreviousRating.PeriodEndDate < WrestlerRating.PeriodEndDate
		order by
				WrestlerPreviousRating.PeriodEndDate desc
		) PreviousRating
where	WeekEvents.SchoolID = 71 -- Fort Mill
group by
		case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
		, EventWrestler.WrestlerName
		, WrestlerRating.Rating
		, PreviousRating.PreviousRating
having	WrestlerRating.Rating - PreviousRating.PreviousRating > 10
)
select	Division
		, [Rank]
		, Wrestler
		, [Key Wins]
from	WrestlerImprovement
where	Rank <= 5
order by
		Division desc
		, [Rank]
