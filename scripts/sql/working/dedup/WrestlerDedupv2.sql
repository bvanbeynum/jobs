declare @LookupID int;
set	@LookupID = 8163;

-- select * from FloWrestler where FirstName + ' ' + LastName like 'T% Wilder'

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	NewID = Original.ID
		, DupID = Dup.ID
		, Wrestler = Original.FirstName + ' ' + Original.LastName
		, Teams = string_agg(Teams.Team, '; ')
		, Events = string_agg(cast(events.EventDate as varchar(max)) + ': ' + events.EventName, '; ') 
			within group (order by events.EventDate desc)
into	#dedup
from	FloWrestler Original
join	FloWrestler Dup
on		Original.FirstName = Dup.FirstName
		and Original.LastName = Dup.LastName
		and Original.ID <> Dup.ID
left join (
		select	FloWrestlerID
				, Team
		from	FloWrestlerMatch
		group by
				FloWrestlerID
				, Team
		union
		select	FloWrestlerID
				, TeamName
		from	FloWrestlerMeet
		group by
				FloWrestlerID
				, TeamName
		) Teams
on		Dup.ID = Teams.FloWrestlerID
left join (
		select	FloWrestlerMatch.FloWrestlerID
				, EventDate = cast(FloMeet.StartTime as date)
				, EventName = FloMeet.MeetName
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		group by
				FloWrestlerMatch.FloWrestlerID
				, cast(FloMeet.StartTime as date)
				, FloMeet.MeetName
		) Events
on		Dup.ID = Events.FloWrestlerID
where	Original.ID = @LookupID
group by
		Original.ID
		, Dup.ID
		, Original.FirstName
		, Original.LastName
order by
		max(Events.EventDate) desc

select	*
from	#dedup

return;

-- delete from #dedup where DupID in (75378)

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

select	count(distinct FloWrestler.ID)
from	FloWrestler
join	#dedup dedup
on		FloWrestler.ID = dedup.DupID;

update	FloWrestlerMatch
set		FloWrestlerID = dedup.NewID
		, ModifiedDate = getdate()
from	FloWrestlerMatch
join	#dedup dedup
on		FloWrestlerMatch.FloWrestlerID = dedup.DupID;

update	FloWrestlerMeet
set		FloWrestlerID = dedup.NewID
		, ModifiedDate = getdate()
from	FloWrestlerMeet
join	#dedup dedup
on		FloWrestlerMeet.FloWrestlerID = dedup.DupID;

delete
from	FloWrestler
from	FloWrestler
join	#dedup dedup
on		FloWrestler.ID = dedup.DupID;

update	FloWrestler
set		ModifiedDate = getdate()
where	FloWrestler.ID in (
			select	distinct NewID
			from	#dedup
		);

commit;

rollback;
