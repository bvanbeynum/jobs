select	Division
		, Rank
		, Wrestler = wrestlername
		, Matches
from	(
		select	Division = case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
				, Rank = rank() over (
					partition by case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end 
					order by count(distinct EventMatch.ID) desc
					)
				, EventWrestler.WrestlerName
				, Matches = count(distinct EventMatch.ID)
		from	#WeekEvents WeekEvents
		join	eventmatch
		on		WeekEvents.EventID = eventmatch.EventID
		join	EventWrestlerMatch
		on		eventmatch.ID = EventWrestlerMatch.EventMatchID
				and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		where	WeekEvents.SchoolID = 71 -- Fort Mill
		group by
				EventWrestler.WrestlerName
				, case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
		) TopMatches
where	Rank <= 5
order by
		Division desc
		, Rank
