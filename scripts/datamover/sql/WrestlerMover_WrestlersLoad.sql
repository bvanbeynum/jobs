select	WrestlerID = EventWrestler.ID
	, WrestlerName = EventWrestler.WrestlerName
	, Rating = EventWrestler.GlickoRating
	, Deviation = EventWrestler.GlickoDeviation
	, LineagePacket = '[' + string_agg('[' + EventWrestlerLineage.Packet + ']', ',') + ']'
from	EventWrestler with (nolock)
join	EventWrestlerMatch with (nolock)
on
		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
left join	EventWrestlerLineage with (nolock)
on
		EventWrestlerLineage.InitialEventWrestlerID = EventWrestler.ID
where	EventWrestlerMatch.ModifiedDate >= dateadd(day, -100, getdate())
		or EventWrestler.ModifiedDate >= dateadd(day, -100, getdate())
group by	EventWrestler.ID
	, EventWrestler.WrestlerName
	, EventWrestler.GlickoRating
	, EventWrestler.GlickoDeviation
order by
		max(EventWrestlerMatch.ModifiedDate) desc
OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;