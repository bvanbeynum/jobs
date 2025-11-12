; with PercentileRatings as (
	select	distinct EventID
			, EventPercentile = percentile_cont(0.9) within group (order by Rating) over (partition by EventID)
	from	#EventRatings
),
TopWrestlers as (
select	EventID
		, Wrestlers = string_agg('- ' + WrestlerName, '\n') within group (order by Rating desc)
from	(
		select	EventID
				, EventWrestler.WrestlerName
				, EventRatings.Rating
				, TopRanking = row_number() over (partition by EventID order by Rating desc)
		from	#EventRatings EventRatings
		join	EventWrestler
		on		EventRatings.EventWrestlerID = EventWrestler.ID
		) WrestlerRanking
where	TopRanking <= 3
group by
		EventID
)
select	top 5 Event = EventRatings.EventName
		, Wrestlers = count(distinct EventRatings.EventWrestlerID)
		, [Top Wrestlers] = TopWrestlers.Wrestlers
from	#EventRatings EventRatings
join	PercentileRatings
on		EventRatings.EventID = PercentileRatings.EventID
join	TopWrestlers
on		EventRatings.EventID = TopWrestlers.EventID
group by
		EventRatings.EventID
		, EventRatings.EventName
		, PercentileRatings.EventPercentile
		, TopWrestlers.Wrestlers
order by
		PercentileRatings.EventPercentile desc;
