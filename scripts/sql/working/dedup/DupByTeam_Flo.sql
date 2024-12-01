
if object_id('tempdb..#WrestlerTeam') is not null
	drop table #WrestlerTeam

if object_id('tempdb..#AllTeamGroup') is not null
	drop table #AllTeamGroup

if object_id('tempdb..#TeamGroup') is not null
	drop table #TeamGroup

if object_id('tempdb..#DupPopulation') is not null
	drop table #DupPopulation

select	Team
		, FloWrestlerID
into	#WrestlerTeam
from	(
		select	FloWrestlerMatch.Team
				, FloWrestlerMatch.FloWrestlerID
				, Wrestlers = count(0) over (partition by FloWrestlerMatch.Team)
		from	FloWrestlerMatch
		where	len(FloWrestlerMatch.Team) > 2
		group by
				FloWrestlerMatch.Team
				, FloWrestlerMatch.FloWrestlerID
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
on		Initial.FloWrestlerID = NextTeam.FloWrestlerID
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
		select	WrestlerGroupID = rank() over (order by FloWrestler.FirstName, FloWrestler.LastName, MatchTeam.GroupID)
				, Dups = count(0) over (partition by FloWrestler.FirstName, FloWrestler.LastName, MatchTeam.GroupID)
				, Priority = row_number() over (partition by FloWrestler.FirstName, FloWrestler.LastName, MatchTeam.GroupID order by count(distinct FloMatch.FloMeetID) desc)
				, WrestlerID = FloWrestler.ID
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, TeamGroupID = MatchTeam.GroupID
				, AllTeams.Teams
				, Events = count(distinct FloMatch.FloMeetID)
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		join	#TeamGroup MatchTeam
		on		FloWrestlerMatch.Team = MatchTeam.Team
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		cross apply (
				select	Teams = string_agg(DistinctTeams.Team, ',')
				from	(
						select	distinct AllTeams.Team
						from	FloWrestlerMatch AllTeams
						where	FloWrestler.ID = AllTeams.FloWrestlerID
						) DistinctTeams
				) AllTeams
		group by
				FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
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

select	SaveID = PrimaryWrestler.WrestlerID
		, DupID = Duplicate.WrestlerID
into	#dedup
from	#DupPopulation PrimaryWrestler
join	#DupPopulation Duplicate
on		PrimaryWrestler.WrestlerGroupID = Duplicate.WrestlerGroupID
		and Duplicate.Priority > 1
where	PrimaryWrestler.Priority = 1;

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
