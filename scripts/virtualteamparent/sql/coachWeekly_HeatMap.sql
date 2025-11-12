; with PercentileRatings as (
	select	distinct WeightClass
			, EventPercentile = percentile_cont(0.8) within group (order by Rating) over (partition by WeightClass)
	from	#EventRatings
)
select	Rank = rank() over (order by PercentileRatings.EventPercentile desc)
		, [Weight Class] = EventRatings.WeightClass
		, Wrestlers = count(distinct EventRatings.EventWrestlerID)
		, [Top Rating] = cast(round(PercentileRatings.EventPercentile, 0) as int)
from	#EventRatings EventRatings
join	PercentileRatings
on		EventRatings.WeightClass = PercentileRatings.WeightClass
where	EventRatings.WeightClass in ('106', '113', '120', '126', '132', '138', '144', '150', '157', '165', '175', '190', '215', '285')
		and (
			coalesce(EventRatings.Division, 'hs') like 'hs%'
			or EventRatings.Division = 'jv'
			or EventRatings.Division like 'high school%'
		)
group by
		EventRatings.WeightClass
		, PercentileRatings.EventPercentile
order by
		PercentileRatings.EventPercentile desc;