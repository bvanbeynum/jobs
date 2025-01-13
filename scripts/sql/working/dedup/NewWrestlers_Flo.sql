
if object_id('tempdb..#newwrestlers') is not null
	drop table #NewWrestlers;

if object_id('tempdb..#PartialNameSameTeam') is not null
	drop table #PartialNameSameTeam;

select	WrestlerID = FloWrestler.ID
into	#NewWrestlers
from	FloWrestler
where	FloWrestler.InsertDate > getdate() - 7

select	distinct NewWrestlerID = FloWrestler.ID
		, ExistingWrestlerID = DupWrestler.ID
		, NewWrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, ExistingWrestler = DupWrestler.FirstName + ' ' + DupWrestler.LastName
		, NewWrestlerTeam = WrestlerTeams.Teams
		, LastEvent = LastMatch.EventDate
into	#PartialNameSameTeam
from	#NewWrestlers NewWrestlers
join	FloWrestler
on		NewWrestlers.WrestlerID = FloWrestler.ID
cross apply (
		select	Teams = '|' + string_agg(Team, '|') + '|'
		from	(
				select	distinct FloWrestlerMatch.FloWrestlerID
						, FloWrestlerMatch.Team
				from	FloWrestlerMatch
				where	NewWrestlers.WrestlerID = FloWrestlerMatch.FloWrestlerID
				) DistinctTeams
		) WrestlerTeams
join	FloWrestler DupWrestler
on		(
			(FloWrestler.FirstName = DupWrestler.FirstName and substring(FloWrestler.LastName, 1, 1) = substring(DupWrestler.LastName, 1, 1))
			or (FloWrestler.LastName = DupWrestler.LastName and substring(FloWrestler.FirstName, 1, 1) = substring(DupWrestler.FirstName, 1, 1))
		)
		and FloWrestler.ID <> DupWrestler.ID
join	FloWrestlerMatch DupWrestlerMatch
on		DupWrestler.ID = DupWrestlerMatch.FloWrestlerID
		and WrestlerTeams.Teams like '%|' + DupWrestlerMatch.Team + '|%'
		and DupWrestlerMatch.InsertDate > getdate() - 545
cross apply (
		select	EventDate = max(cast(FloMeet.StartTime as date))
		from	FloWrestlerMatch LastMatch
		join	FloMatch
		on		LastMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	DupWrestlerMatch.FloWrestlerID = LastMatch.FloWrestlerID
		) LastMatch

select	SaveID = ExistingWrestlerID
		, DupID = NewWrestlerID
		, NewWrestler
		, ExistingWrestler
		, NewWrestlerTeam = replace(NewWrestlerTeam, '|', '')
		, LastEvent
from	#PartialNameSameTeam
order by
		NewWrestlerTeam
		, NewWrestler
		, ExistingWrestler


return;

if object_id('tempdb..#dedup') is not null
	drop table #dedup;

create table #dedup (
	SaveID int
	, DupID int
)

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct FloWrestlerMatch.ID) from FloWrestlerMatch join #dedup dedup on FloWrestlerMatch.FloWrestlerID = dedup.DupID)
		, TempMeets = (select count(distinct FloWrestlerMeet.ID) from FloWrestlerMeet join #dedup dedup on FloWrestlerMeet.FloWrestlerID = dedup.DupID)
		, Predictions = (select count(distinct GlickoPrediction.ID) from GlickoPrediction join #dedup dedup on GlickoPrediction.Wrestler1FloID = dedup.DupID or GlickoPrediction.Wrestler2FloID = dedup.DupID)

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
