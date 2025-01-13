
if object_id('tempdb..#FullDups') is not null
	drop table #FullDups;

with Track as (
select	distinct WrestlerID = TrackWrestlerMatch.TrackWrestlerID
		, TrackWrestlerMatch.WrestlerName
		, WrestlerTeams.AllTeams
from	TrackWrestlerMatch
left join (
		select	TrackWrestlerID
				, AllTeams = '|' + string_agg(Team, '|') + '|'
		from	(
				select	distinct TrackWrestlerID
						, Team
				from	TrackWrestlerMatch
				) DistinctTeam
		group by
				TrackWrestlerID
		) WrestlerTeams
on		TrackWrestlerMatch.TrackWrestlerID = WrestlerTeams.TrackWrestlerID
), Flo as (
select	distinct WrestlerID = FloWrestlerMatch.FloWrestlerID
		, WrestlerName = FloWrestlerMatch.FirstName + ' ' + FloWrestlerMatch.LastName
		, FloWrestlerMatch.Team
from	FloWrestlerMatch
)
select	DupFlo.GroupID
		, TrackWrestlerName = TrackWrestler.WrestlerName
		, TrackTeams = string_agg(track.AllTeams, '|')
		, DupFlo.FloWrestlerID
		, FloWrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloTeams = string_agg(flo.Team, '|')
into	#FullDups
from	(
		select	GroupID = Track.WrestlerID
				, FloWrestlerID = flo.WrestlerID
				, GroupFilter = count(0) over (partition by Track.WrestlerID)
		from	Track
		join	Flo
		on		Track.WrestlerName = Flo.WrestlerName
				and track.AllTeams like '%|' + flo.Team + '|%'
		join	FloWrestler
		on		flo.WrestlerID = FloWrestler.ID
		group by
				Track.WrestlerID
				, flo.WrestlerID
		) DupFlo
join	TrackWrestler
on		DupFlo.GroupID = TrackWrestler.ID
join	track
on		DupFlo.GroupID = track.WrestlerID
join	FloWrestler
on		DupFlo.FloWrestlerID = FloWrestler.ID
join	Flo
on		DupFlo.FloWrestlerID = flo.WrestlerID
where	DupFlo.GroupFilter > 1
group by
		DupFlo.GroupID
		, TrackWrestler.WrestlerName
		, DupFlo.FloWrestlerID
		, FloWrestler.FirstName + ' ' + FloWrestler.LastName
order by
		DupFlo.GroupID

return;

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

if object_id('tempdb..#dedup') is not null
	drop table #dedup;

select	SaveDup.SaveID
		, DupID = DeDup.FloWrestlerID
into	#dedup
from	(
		select	GroupID
				, SaveID = min(FloWrestlerID)
		from	#FullDups
		group by
				GroupID
		) SaveDup
join	#FullDups DeDup
on		SaveDup.GroupID = DeDup.GroupID
		and SaveDup.SaveID <> DeDup.FloWrestlerID

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

/*

commit;

rollback;

*/
