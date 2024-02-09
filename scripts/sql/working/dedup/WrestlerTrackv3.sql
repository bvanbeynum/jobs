
-- select * from TrackWrestler where WrestlerName like 'A% Lopez'

if object_id('tempdb..#dedup') is not null
	drop table #dedup

declare @LookupID int;
declare @Length int;

set	@LookupID = 85717;
set @Length = 1;

select	SaveID = TrackWrestler.ID
		, DupID = Dup.ID
		, Wrestler = TrackWrestler.WrestlerName
		, DupName = Dup.WrestlerName
		, WrestlerTeam = TrackWrestlerMatch.Team
		, AllTeams.DupTeams
		, AllEvents.Events
into	#dedup
from	TrackWrestlerMatch
join	TrackWrestler
on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
join	TrackWrestlerMatch SameTeam
on		TrackWrestlerMatch.Team = SameTeam.Team
join	TrackWrestler Dup
on		SameTeam.TrackWrestlerID = Dup.ID
outer apply (
		select	string_agg(team, '; ') DupTeams
		from	(
				select	Teams.Team
				from	TrackWrestlerMatch Teams
				where	Dup.ID = Teams.TrackWrestlerID
				group by
						Teams.Team
				) Teams
		) AllTeams
outer apply (
		select	Events = string_agg(cast(EventDate as varchar(max)) + ': ' + EventName, '; ') 
					within group (order by EventDate desc)
		from	(
				select	EventWrestlerMatch.TrackWrestlerID
						, EventDate = Events.EventDate
						, EventName = Events.EventName
				from	TrackWrestlerMatch EventWrestlerMatch
				join	TrackMatch EventMatch
				on		EventWrestlerMatch.TrackMatchID = EventMatch.ID
				join	TrackEvent Events
				on		EventMatch.TrackEventID = Events.ID
				where	Dup.ID = EventWrestlerMatch.TrackWrestlerID
				group by
						EventWrestlerMatch.TrackWrestlerID
						, Events.EventDate
						, Events.EventName
				) WrestlerEvents
		) AllEvents
where	TrackWrestler.ID <> Dup.ID
		and substring(TrackWrestler.WrestlerName, charindex(' ', TrackWrestler.WrestlerName), len(TrackWrestler.WrestlerName)) = substring(Dup.WrestlerName, charindex(' ', Dup.WrestlerName), len(Dup.WrestlerName))
		and substring(TrackWrestler.WrestlerName, 1, @Length) = substring(Dup.WrestlerName, 1, @Length)
		and TrackWrestler.ID = @LookupID
group by
		TrackWrestler.ID
		, Dup.ID
		, TrackWrestler.WrestlerName
		, Dup.WrestlerName
		, TrackWrestlerMatch.Team
		, AllTeams.DupTeams
		, AllEvents.Events;

select	*
from	#dedup
order by
		DupName;

return;

-- delete from #dedup where DupID in (69687)

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
set		TrackWrestlerID = dedup.SaveID
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
			select	distinct SaveID
			from	#dedup
		);

commit;

rollback;
