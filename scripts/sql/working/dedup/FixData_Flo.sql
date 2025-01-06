/*

commit;

rollback;

*/

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	SaveID = 102293
		, DupID = FloWrestler.ID
into	#dedup
from	FloWrestler
where	FloWrestler.ID in (120941);

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct FloWrestlerMatch.ID) from FloWrestlerMatch join #dedup dedup on FloWrestlerMatch.FloWrestlerID = dedup.DupID)
		, TempMeets = (select count(distinct FloWrestlerMeet.ID) from FloWrestlerMeet join #dedup dedup on FloWrestlerMeet.FloWrestlerID = dedup.DupID)
		, Predictions = (select count(distinct GlickoPrediction.ID) from GlickoPrediction join #dedup dedup on GlickoPrediction.Wrestler1FloID = dedup.DupID or GlickoPrediction.Wrestler2FloID = dedup.DupID)

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
