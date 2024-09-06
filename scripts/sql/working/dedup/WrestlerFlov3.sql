
-- select * from FloWrestler where FirstName + ' ' + LastName like 'j% Stocker'

if object_id('tempdb..#dedup') is not null
	drop table #dedup

declare @LookupID int;
declare @Length int;

set	@LookupID = 727;
set @Length = 1;

select	SaveID = FloWrestler.ID
		, DupID = Dup.ID
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, DupName = Dup.FirstName + ' ' + dup.LastName
		, WrestlerTeam = FloWrestlerMatch.Team
		, AllTeams.DupTeams
		, AllEvents.Events
into	#dedup
from	FloWrestlerMatch
join	FloWrestler
on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
join	FloWrestlerMatch SameTeam
on		FloWrestlerMatch.Team = SameTeam.Team
join	FloWrestler Dup
on		SameTeam.FloWrestlerID = Dup.ID
outer apply (
		select	string_agg(team, '; ') DupTeams
		from	(
				select	Teams.Team
				from	FloWrestlerMatch Teams
				where	Dup.ID = Teams.FloWrestlerID
				group by
						Teams.Team
				) Teams
		) AllTeams
outer apply (
		select	Events = string_agg(cast(EventDate as varchar(max)) + ': ' + EventName, '; ') 
					within group (order by EventDate desc)
		from	(
				select	EventWrestlerMatch.FloWrestlerID
						, EventDate = cast(Events.StartTime as date)
						, EventName = Events.MeetName
				from	FloWrestlerMatch EventWrestlerMatch
				join	FloMatch EventMatch
				on		EventWrestlerMatch.FloMatchID = EventMatch.ID
				join	FloMeet Events
				on		EventMatch.FloMeetID = Events.ID
				where	Dup.ID = EventWrestlerMatch.FloWrestlerID
				group by
						EventWrestlerMatch.FloWrestlerID
						, Events.StartTime
						, Events.MeetName
				) WrestlerEvents
		) AllEvents
where	FloWrestler.ID <> Dup.ID
		and FloWrestler.LastName = Dup.LastName
		and substring(FloWrestler.FirstName, 1, @Length) = substring(Dup.FirstName, 1, @Length)
		and FloWrestler.ID = @LookupID
group by
		FloWrestler.ID
		, Dup.ID
		, FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, Dup.FirstName + ' ' + dup.LastName
		, FloWrestlerMatch.Team
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

select	Matches = count(distinct FloWrestlerMatch.ID)
from	FloWrestlerMatch
join	#dedup dedup
on		FloWrestlerMatch.FloWrestlerID = dedup.DupID;

select	count(distinct FloWrestler.ID)
from	FloWrestler
join	#dedup dedup
on		FloWrestler.ID = dedup.DupID;

update	FloWrestlerMatch
set		FloWrestlerID = dedup.SaveID
from	FloWrestlerMatch
join	#dedup dedup
on		FloWrestlerMatch.FloWrestlerID = dedup.DupID;

delete
from	FloWrestler
from	FloWrestler
join	#dedup dedup
on		FloWrestler.ID = dedup.DupID;

update	FloWrestler
set		ModifiedDate = getdate()
where	FloWrestler.ID in (
			select	distinct SaveID
			from	#dedup
		);

commit;

rollback;
