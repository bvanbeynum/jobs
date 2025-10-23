select	WrestlerID = EventWrestler.ID
		, WrestlerName = EventWrestler.WrestlerName
		, Rating = EventWrestler.GlickoRating
		, Deviation = EventWrestler.GlickoDeviation
		, LineagePacket = '[' + string_agg('[' + EventWrestlerLineage.Packet + ']', ',') + ']'
from	EventWrestler with (nolock)
join	EventWrestlerMatch with (nolock)
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
left join
		EventWrestlerLineage with (nolock)
on		EventWrestlerLineage.InitialEventWrestlerID = EventWrestler.ID
where	EventWrestler.id in (
			select	distinct EventWrestler.ID
			from	EventWrestler
			join	EventWrestlerMatch
			on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
			join	EventMatch
			on		EventWrestlerMatch.EventMatchID = EventMatch.ID
			join	Event
			on		EventMatch.EventID = Event.ID
			where	Event.EventDate > getdate() - 720
		)
		and (
			EventWrestlerMatch.ModifiedDate >= dateadd(day, -8, getdate())
			or EventWrestler.ModifiedDate >= dateadd(day, -8, getdate())
		)
group by
		EventWrestler.ID
		, EventWrestler.WrestlerName
		, EventWrestler.GlickoRating
		, EventWrestler.GlickoDeviation
order by
		max(EventWrestlerMatch.ModifiedDate) desc
OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;