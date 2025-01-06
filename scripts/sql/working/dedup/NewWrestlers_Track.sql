
if object_id('tempdb..#newwrestlers') is not null
	drop table #NewWrestlers;

if object_id('tempdb..#PartialNameSameTeam') is not null
	drop table #PartialNameSameTeam;

select	WrestlerID = TrackWrestler.ID
into	#NewWrestlers
from	TrackWrestler
where	TrackWrestler.InsertDate > getdate() - 3

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
