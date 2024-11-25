
-- select * from FloWrestler where FirstName + ' ' + LastName like 'j% Stocker'

if object_id('tempdb..#dedup') is not null
	drop table #dedup

declare @LookupID int;
declare @Length int;

set	@LookupID = 1402;
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

-- delete from #dedup where DupID in (3633, 82252)

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

select	Matches = count(distinct FloWrestlerMatch.ID)
from	FloWrestlerMatch
join	#dedup dedup
on		FloWrestlerMatch.FloWrestlerID = dedup.DupID;

select	Meets = count(distinct FloWrestlerMeet.ID)
from	FloWrestlerMeet
join	#dedup dedup
on		FloWrestlerMeet.FloWrestlerID = dedup.DupID;

select	Predictions = count(distinct GlickoPrediction.ID)
from	GlickoPrediction
join	#dedup dedup
on		GlickoPrediction.Wrestler1FloID = dedup.DupID
		or GlickoPrediction.Wrestler2FloID = dedup.DupID

select	count(distinct FloWrestler.ID)
from	FloWrestler
join	#dedup dedup
on		FloWrestler.ID = dedup.DupID;

update	FloWrestlerMatch
set		FloWrestlerID = dedup.SaveID
		, ModifiedDate = getdate()
from	FloWrestlerMatch
join	#dedup dedup
on		FloWrestlerMatch.FloWrestlerID = dedup.DupID;

update	FloWrestlerMeet
set		FloWrestlerID = dedup.SaveID
		, ModifiedDate = getdate()
from	FloWrestlerMeet
join	#dedup dedup
on		FloWrestlerMeet.FloWrestlerID = dedup.DupID;

update	GlickoPrediction
set		GlickoPrediction.Wrestler1FloID = case when GlickoPrediction.Wrestler1FloID = dedup.DupID then dedup.SaveID else GlickoPrediction.Wrestler1FloID end
		, GlickoPrediction.Wrestler2FloID = case when GlickoPrediction.Wrestler2FloID = dedup.DupID then dedup.SaveID else GlickoPrediction.Wrestler2FloID end
from	GlickoPrediction
join	#dedup dedup
on		GlickoPrediction.Wrestler1FloID = dedup.DupID
		or GlickoPrediction.Wrestler2FloID = dedup.DupID

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
