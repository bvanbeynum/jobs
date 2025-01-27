
if object_id('tempdb..#dups') is not null
	drop table #dups

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	GroupID
		, Priority
		, WrestlerID
		, FirstName
		, LastName
		, WrestlerTeams.Teams
into	#Dups
from	(
		select	GroupID = rank() over (order by FloWrestler.FirstName, FloWrestler.LastName, FloWrestlerMatch.Team)
				, Priority = row_number() over (partition by FloWrestler.FirstName, FloWrestler.LastName, FloWrestlerMatch.Team order by FloWrestler.ID)
				, WrestlerID = FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestlerMatch.Team
				, Wrestlers = count(0) over (partition by FloWrestler.FirstName, FloWrestler.LastName, FloWrestlerMatch.Team)
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		group by
				FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestlerMatch.Team
		) DupWrestlers
cross apply (
		select	Teams = string_agg(team, ', ')
		from	(
				select	distinct FloWrestlerMatch.Team
				from	FloWrestlerMatch
				where	DupWrestlers.WrestlerID = FloWrestlerMatch.FloWrestlerID
				) WrestlerTeamsGroup
		) WrestlerTeams
where	Wrestlers > 1
order by
		GroupID
		, WrestlerID
		, FirstName
		, LastName
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
		, Matches = (select count(distinct FloWrestlerMatch.ID) from FloWrestlerMatch join #dedup dedup on FloWrestlerMatch.FloWrestlerID = dedup.DupID)
		, TempMeets = (select count(distinct FloWrestlerMeet.ID) from FloWrestlerMeet join #dedup dedup on FloWrestlerMeet.FloWrestlerID = dedup.DupID)
		, Predictions = (select count(distinct GlickoPrediction.ID) from GlickoPrediction join #dedup dedup on GlickoPrediction.Wrestler1FloID = dedup.DupID or GlickoPrediction.Wrestler2FloID = dedup.DupID)
		, LineageInitial = (select count(0) from WrestlerLineage join #dedup dedup on WrestlerLineage.InitialFloID = dedup.DupID)
		, LineageWrestler2 = (select count(0) from WrestlerLineage join #dedup dedup on WrestlerLineage.Wrestler2FloID = dedup.DupID)

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

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

update	WrestlerLineage
set		InitialFloID = dedup.SaveID
from	WrestlerLineage
join	#dedup dedup
on		WrestlerLineage.InitialFloID = dedup.DupID;

update	WrestlerLineage
set		InitialFloID = dedup.SaveID
from	WrestlerLineage
join	#dedup dedup
on		WrestlerLineage.Wrestler2FloID = dedup.DupID;

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

/*

commit;

rollback;

*/
