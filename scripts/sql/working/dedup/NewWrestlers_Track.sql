
if object_id('tempdb..#newwrestlers') is not null
	drop table #NewWrestlers;

if object_id('tempdb..#PartialNameSameTeam') is not null
	drop table #PartialNameSameTeam;

select	WrestlerID = TrackWrestler.ID
into	#NewWrestlers
from	TrackWrestler
where	TrackWrestler.InsertDate > getdate() - 7

select	distinct NewWrestlerID = TrackWrestler.ID
		, ExistingWrestlerID = DupWrestler.ID
		, NewWrestler = TrackWrestler.WrestlerName
		, ExistingWrestler = DupWrestler.WrestlerName
		, NewWrestlerTeam = WrestlerTeams.Teams
		, LastEvent = LastMatch.EventDate
into	#PartialNameSameTeam
from	#NewWrestlers NewWrestlers
join	TrackWrestler
on		NewWrestlers.WrestlerID = TrackWrestler.ID
cross apply (
		select	Teams = '|' + string_agg(Team, '|') + '|'
		from	(
				select	distinct TrackWrestlerMatch.TrackWrestlerID
						, TrackWrestlerMatch.Team
				from	TrackWrestlerMatch
				where	NewWrestlers.WrestlerID = TrackWrestlerMatch.TrackWrestlerID
				) DistinctTeams
		) WrestlerTeams
join	TrackWrestler DupWrestler
on		(
			(
				substring(TrackWrestler.WrestlerName, 0, charindex(' ', TrackWrestler.WrestlerName)) = substring(DupWrestler.WrestlerName, 0, charindex(' ', DupWrestler.WrestlerName))
				and substring(TrackWrestler.WrestlerName, charindex(' ', TrackWrestler.WrestlerName) + 1, 1) = substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, 1)
			)
			or (
				substring(TrackWrestler.WrestlerName, charindex(' ', TrackWrestler.WrestlerName) + 1, len(TrackWrestler.WrestlerName)) = substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, len(DupWrestler.WrestlerName))
				and substring(TrackWrestler.WrestlerName, 1, 1) = substring(DupWrestler.WrestlerName, 1, 1)
			)
		)
		and TrackWrestler.ID <> DupWrestler.ID
join	TrackWrestlerMatch DupWrestlerMatch
on		DupWrestler.ID = DupWrestlerMatch.TrackWrestlerID
		and WrestlerTeams.Teams like '%|' + DupWrestlerMatch.Team + '|%'
		and DupWrestlerMatch.InsertDate > getdate() - 545
cross apply (
		select	EventDate = max(cast(TrackEvent.EventDate as date))
		from	TrackWrestlerMatch LastMatch
		join	TrackMatch
		on		LastMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	DupWrestlerMatch.TrackWrestlerID = LastMatch.TrackWrestlerID
		) LastMatch

select	ExistingID = ExistingWrestlerID
		, NewID = NewWrestlerID
		, ExistingWrestler
		, NewWrestler
		, Team = replace(NewWrestlerTeam, '|', '')
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
