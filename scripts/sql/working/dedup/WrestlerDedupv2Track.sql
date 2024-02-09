
-- select * from TrackWrestler where WrestlerName like 'T% Wilder'

if object_id('tempdb..#dedup') is not null
	drop table #dedup

declare @LookupID int;
set	@LookupID = 29960;

select	NewID = Original.ID
		, DupID = Dup.ID
		, Wrestler = Original.WrestlerName
		, Teams = string_agg(Teams.Team, '; ')
		, Events = string_agg(cast(events.EventDate as varchar(max)) + ': ' + events.EventName, '; ') 
			within group (order by events.EventDate desc)
into	#dedup
from	TrackWrestler Original
join	TrackWrestler Dup
on		Original.WrestlerName = Dup.WrestlerName
		and Original.ID <> Dup.ID
left join (
		select	TrackWrestlerID
				, Team
		from	TrackWrestlerMatch
		group by
				TrackWrestlerID
				, Team
		) Teams
on		Dup.ID = Teams.TrackWrestlerID
left join (
		select	TrackWrestlerMatch.TrackWrestlerID
				, EventDate = cast(TrackEvent.EventDate as date)
				, EventName = TrackEvent.EventName
		from	TrackWrestlerMatch
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		group by
				TrackWrestlerMatch.TrackWrestlerID
				, cast(TrackEvent.EventDate as date)
				, TrackEvent.EventName
		) Events
on		Dup.ID = Events.TrackWrestlerID
where	Original.ID = @LookupID
group by
		Original.ID
		, Dup.ID
		, Original.WrestlerName
order by
		max(Events.EventDate) desc

select	*
from	#dedup

return;

-- delete from #dedup where DupID in (5906, 6840)

select @@trancount

begin transaction;

select	Matches = count(distinct TrackWrestlerMatch.ID)
from	TrackWrestlerMatch
join	#dedup dedup
on		TrackWrestlerMatch.TrackWrestlerID = dedup.DupID;

select	count(distinct TrackWrestler.ID)
from	TrackWrestler
join	#dedup dedup
on		TrackWrestler.ID = dedup.DupID;

update	TrackWrestlerMatch
set		TrackWrestlerID = dedup.NewID
		, ModifiedDate = getdate()
from	TrackWrestlerMatch
join	#dedup dedup
on		TrackWrestlerMatch.TrackWrestlerID = dedup.DupID;

delete
from	TrackWrestler
from	TrackWrestler
join	#dedup dedup
on		TrackWrestler.ID = dedup.DupID;

update	TrackWrestler
set		ModifiedDate = getdate()
where	TrackWrestler.ID in (
			select	distinct NewID
			from	#dedup
		);

commit;

rollback;
