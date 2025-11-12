;with WrestlerBonus as (
select	Division = case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
		, Rank = rank() over (
			partition by case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
			order by sum(case 
				when eventmatch.wintype = 'f' or eventmatch.WinType like '%fall%' or EventMatch.WinType like '%for%' then 2
				when eventmatch.wintype = '%tf%'then 1.5
				when eventmatch.wintype = '%md%' or eventmatch.WinType like 'maj%' then 1.5
				end) desc
			)
		, Wrestler = EventWrestler.WrestlerName
		, [Bonus Points] = sum(case 
			when eventmatch.wintype = 'f' or eventmatch.WinType like '%fall%' or EventMatch.WinType like '%for%' then 2
			when eventmatch.wintype = '%tf%'then 1.5
			when eventmatch.wintype = '%md%' or eventmatch.WinType like 'maj%' then 1.5
			end)
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
		and EventWrestlerMatch.IsWinner = 1
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
where	WeekEvents.SchoolID = 71 -- Fort Mill
group by
		EventWrestler.WrestlerName
		, case when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity' else 'JV' end
)
select	Division
		, [Rank]
		, Wrestler
		, [Bonus Points]
from	WrestlerBonus
where	Rank <= 5
order by
		Division desc
		, [Rank]
		, Wrestler
