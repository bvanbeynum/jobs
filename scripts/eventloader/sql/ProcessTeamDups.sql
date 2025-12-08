
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

-- ****************** Build the team groups *****************

-- All teams
select	TeamName
		, EventWrestlerID
into	#AllTeams
from	(
		select	EventWrestlerMatch.TeamName
				, EventWrestlerMatch.EventWrestlerID
				, Wrestlers = count(0) over (partition by EventWrestlerMatch.TeamName)
		from	EventWrestlerMatch
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		where	len(EventWrestlerMatch.TeamName) > 2
				and len(trim(EventWrestler.WrestlerName)) > 0
		group by
				EventWrestlerMatch.TeamName
				, EventWrestlerMatch.EventWrestlerID
		) WrestlerTeam
where	Wrestlers < 500
order by
		Wrestlers desc;

-- Get the baseline for the teams
select	TeamID = row_number() over (order by TeamName)
		, TeamName
		, Iteration = cast(1 as int)
into	#AllTeamGroup
from	#AllTeams
group by
		TeamName;

-- Iterate to get N levels deep of teams

declare @Iteration int = 1;

while @Iteration <= 2
begin
	insert	#AllTeamGroup (
			TeamID
			, TeamName
			, Iteration
			)
	select	AllTeam.TeamID
			, NextTeam.TeamName
			, AllTeam.Iteration + 1
	from	#AllTeamGroup AllTeam
	join	#AllTeams Initial
	on		AllTeam.TeamName = Initial.TeamName
	join	#AllTeams NextTeam
	on		Initial.EventWrestlerID = NextTeam.EventWrestlerID
			and Initial.TeamName <> NextTeam.TeamName
	left join
			#AllTeamGroup Excluded
	on		NextTeam.TeamName = Excluded.TeamName
			and AllTeam.TeamID = Excluded.TeamID
	where	Excluded.TeamName is null
			and AllTeam.Iteration = @Iteration
	group by
			AllTeam.TeamID
			, NextTeam.TeamName
			, AllTeam.Iteration;

	set @Iteration = @Iteration + 1;
end

-- Create the group ID
select	GroupID = min(TeamID)
		, TeamName
into	#TeamGroup
from	#AllTeamGroup
group by
		TeamName;

select	*
into	#DupPopulation
from	(
		select	WrestlerGroupID = rank() over (order by EventWrestler.WrestlerName, MatchTeam.GroupID)
				, Dups = count(0) over (partition by EventWrestler.WrestlerName, MatchTeam.GroupID)
				, Priority = row_number() over (partition by EventWrestler.WrestlerName, MatchTeam.GroupID order by EventWrestler.GlickoRating desc)
				, WrestlerID = EventWrestler.ID
				, EventWrestler.WrestlerName
				, TeamGroupID = MatchTeam.GroupID
				-- , EventWrestler.GlickoRating
				, AllTeams.Teams
				, Events = count(distinct EventMatch.EventID)
		from	EventWrestler
		join	EventWrestlerMatch
		on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
		join	#TeamGroup MatchTeam
		on		EventWrestlerMatch.TeamName = MatchTeam.TeamName
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		cross apply (
				select	Teams = string_agg(DistinctTeams.TeamName, ',') within group (order by DistinctTeams.TeamName)
				from	(
						select	distinct AllTeams.TeamName
						from	EventWrestlerMatch AllTeams
						where	EventWrestler.ID = AllTeams.EventWrestlerID
						) DistinctTeams
				) AllTeams
		where	len(trim(EventWrestler.WrestlerName)) > 0
		group by
				EventWrestler.ID
				, EventWrestler.WrestlerName
				, EventWrestler.GlickoRating
				, MatchTeam.GroupID
				, AllTeams.Teams
		) DupWrestlers
where	Dups > 1
order by
		Dups desc
		, TeamGroupID
		, WrestlerName
		, Events desc

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
order by
		SaveID;

update	EventWrestlerMatch
set		EventWrestlerID = dedup.SaveID
		, ModifiedDate = getdate()
from	EventWrestlerMatch
join	#dedup dedup
on		EventWrestlerMatch.EventWrestlerID = dedup.DupID;

delete
from	EventWrestler
from	EventWrestler
join	#dedup dedup
on		EventWrestler.ID = dedup.DupID;

update	EventWrestler
set		ModifiedDate = getdate()
where	EventWrestler.ID in (
			select	distinct SaveID
			from	#dedup
		);
