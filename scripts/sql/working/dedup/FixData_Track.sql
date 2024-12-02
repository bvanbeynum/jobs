/*

commit;

rollback;

*/

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	SaveID = 7148
		, DupID = TrackWrestler.ID
into	#dedup
from	TrackWrestler
where	TrackWrestler.ID in (27421, 66209, 107128, 8632, 103817);

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
