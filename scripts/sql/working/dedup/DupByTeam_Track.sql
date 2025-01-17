
if object_id('tempdb..#WrestlerTeam') is not null
	drop table #WrestlerTeam

if object_id('tempdb..#AllTeamGroup') is not null
	drop table #AllTeamGroup

if object_id('tempdb..#TeamGroup') is not null
	drop table #TeamGroup

if object_id('tempdb..#DupPopulation') is not null
	drop table #DupPopulation

if object_id('tempdb..#DupPopulation') is not null
	drop table #DupPopulation

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	Team
		, TrackWrestlerID
into	#WrestlerTeam
from	(
		select	TrackWrestlerMatch.Team
				, TrackWrestlerMatch.TrackWrestlerID
				, Wrestlers = count(0) over (partition by TrackWrestlerMatch.Team)
		from	TrackWrestlerMatch
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		where	len(TrackWrestlerMatch.Team) > 2
				and len(trim(TrackWrestler.WrestlerName)) > 0
		group by
				TrackWrestlerMatch.Team
				, TrackWrestlerMatch.TrackWrestlerID
		) WrestlerTeam
where	Wrestlers < 500
order by
		Wrestlers desc

select	TeamID = row_number() over (order by team)
		, Team
		, Iteration = cast(1 as int)
into	#AllTeamGroup
from	#WrestlerTeam
group by
		Team

insert	#AllTeamGroup (
		TeamID
		, Team
		, Iteration
		)
select	AllTeam.TeamID
		, NextTeam.Team
		, AllTeam.Iteration + 1
from	#AllTeamGroup AllTeam
join	#WrestlerTeam Initial
on		AllTeam.Team = Initial.Team
join	#WrestlerTeam NextTeam
on		Initial.TrackWrestlerID = NextTeam.TrackWrestlerID
		and Initial.Team <> NextTeam.Team
left join
		#AllTeamGroup Excluded
on		NextTeam.Team = Excluded.Team
		and AllTeam.TeamID = Excluded.TeamID
where	Excluded.Team is null
		and AllTeam.Iteration = 1
group by
		AllTeam.TeamID
		, NextTeam.Team
		, AllTeam.Iteration

select	GroupID = min(TeamID)
		, Team
into	#TeamGroup
from	#AllTeamGroup
group by
		Team

select	*
into	#DupPopulation
from	(
		select	WrestlerGroupID = rank() over (order by TrackWrestler.WrestlerName, MatchTeam.GroupID)
				, Dups = count(0) over (partition by TrackWrestler.WrestlerName, MatchTeam.GroupID)
				, Priority = row_number() over (partition by TrackWrestler.WrestlerName, MatchTeam.GroupID order by count(distinct TrackMatch.TrackEventID) desc)
				, WrestlerID = TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, TeamGroupID = MatchTeam.GroupID
				, AllTeams.Teams
				, Events = count(distinct TrackMatch.TrackEventID)
		from	TrackWrestler
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		join	#TeamGroup MatchTeam
		on		TrackWrestlerMatch.Team = MatchTeam.Team
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		cross apply (
				select	Teams = string_agg(DistinctTeams.Team, ',')
				from	(
						select	distinct AllTeams.Team
						from	TrackWrestlerMatch AllTeams
						where	TrackWrestler.ID = AllTeams.TrackWrestlerID
						) DistinctTeams
				) AllTeams
		where	len(trim(TrackWrestler.WrestlerName)) > 0
		group by
				TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, MatchTeam.GroupID
				, AllTeams.Teams
		) DupWrestlers
where	Dups > 1
order by
		Dups desc
		, TeamGroupID
		, WrestlerName
		, Events desc

select	*
from	#DupPopulation
order by
		Dups desc
		, TeamGroupID
		, WrestlerName
		, Events desc

return;

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

select	SaveID = PrimaryWrestler.WrestlerID
		, DupID = Duplicate.WrestlerID
into	#dedup
from	#DupPopulation PrimaryWrestler
join	#DupPopulation Duplicate
on		PrimaryWrestler.WrestlerGroupID = Duplicate.WrestlerGroupID
		and Duplicate.Priority > 1
where	PrimaryWrestler.Priority = 1
group by
		PrimaryWrestler.WrestlerID
		, Duplicate.WrestlerID

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct TrackWrestlerMatch.ID) from TrackWrestlerMatch join #dedup dedup on TrackWrestlerMatch.TrackWrestlerID = dedup.DupID)

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
