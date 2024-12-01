
if object_id('tempdb..#dups') is not null
	drop table #dups

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	GroupID
		, Priority
		, WrestlerID
		, WrestlerName
		, WrestlerTeams.Teams
into	#Dups
from	(
		select	GroupID = rank() over (order by TrackWrestler.WrestlerName, TrackWrestlerMatch.Team)
				, Priority = row_number() over (partition by TrackWrestler.WrestlerName, TrackWrestlerMatch.Team order by TrackWrestler.ID)
				, WrestlerID = TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, TrackWrestlerMatch.Team
				, Wrestlers = count(0) over (partition by TrackWrestler.WrestlerName, TrackWrestlerMatch.Team)
		from	TrackWrestler
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		group by
				TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, TrackWrestlerMatch.Team
		) DupWrestlers
cross apply (
		select	Teams = string_agg(team, ', ')
		from	(
				select	distinct TrackWrestlerMatch.Team
				from	TrackWrestlerMatch
				where	DupWrestlers.WrestlerID = TrackWrestlerMatch.TrackWrestlerID
				) WrestlerTeamsGroup
		) WrestlerTeams
where	Wrestlers > 1
order by
		GroupID
		, WrestlerID
		, WrestlerName
		, Team

select	SaveID = PrimaryWrestler.WrestlerID
		, DupID = Duplicate.WrestlerID
into	#dedup
from	#Dups PrimaryWrestler
join	#Dups Duplicate
on		PrimaryWrestler.GroupID = Duplicate.GroupID
		and Duplicate.Priority > 1
where	PrimaryWrestler.Priority = 1;

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct TrackWrestlerMatch.ID) from TrackWrestlerMatch join #dedup dedup on TrackWrestlerMatch.TrackWrestlerID = dedup.DupID)

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

update	TrackWrestlerMatch
set		TrackWrestlerID = dedup.SaveID
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
			select	distinct SaveID
			from	#dedup
		);

/*

commit;

rollback;

*/
