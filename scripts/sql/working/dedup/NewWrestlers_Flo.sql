
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
