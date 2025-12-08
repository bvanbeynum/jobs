
set nocount on;

if object_id('tempdb..#AllTeams') is not null
	drop table #AllTeams;

if object_id('tempdb..#AllTeamGroup') is not null
	drop table #AllTeamGroup;

if object_id('tempdb..#TeamGroup') is not null
	drop table #TeamGroup;

if object_id('tempdb..#newwrestlers') is not null
	drop table #NewWrestlers;

if object_id('tempdb..#DupWrestlers') is not null
	drop table #DupWrestlers;

if object_id('tempdb..#Matches') is not null
	drop table #Matches;

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

-- Get all the newest wrestlers
select	WrestlerID = EventWrestler.ID
		, WrestlerName = EventWrestler.WrestlerName
		, FirstName = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, 1, charindex(' ', EventWrestler.WrestlerName) - 1) else EventWrestler.WrestlerName end
		, FirstInitial = substring(EventWrestler.WrestlerName, 1, 1)
		, LastName = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, charindex(' ', EventWrestler.WrestlerName) + 1, len(EventWrestler.WrestlerName)) else EventWrestler.WrestlerName end
		, LastInitial = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, charindex(' ', EventWrestler.WrestlerName) + 1, 1) else EventWrestler.WrestlerName end
		, GroupID = TeamGroup.GroupID
into	#NewWrestlers
from	EventWrestler
cross apply (
		select	GroupID = max(TeamGroup.GroupID)
		from	EventWrestlerMatch
		join	#TeamGroup TeamGroup
		on		EventWrestlerMatch.TeamName = TeamGroup.TeamName
		where	EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		) TeamGroup
where	EventWrestler.InsertDate > getdate() - 3 -- Since it runs daily, only get wrestlers in the last 3 days
		and len(trim(EventWrestler.WrestlerName)) > 0;

-- Get the dataset of all the existing wrestlers
;with TeamGroup as (
select	EventWrestlerID
		, Groups = '|' + string_agg(cast(GroupID as varchar), '|') within group (order by GroupID) + '|'
from	(
		select	distinct EventWrestlerMatch.EventWrestlerID
				, TeamGroup.GroupID
		from	EventWrestlerMatch
		join	#TeamGroup TeamGroup
		on		EventWrestlerMatch.TeamName = TeamGroup.TeamName
		) TeamGroups
group by
		EventWrestlerID
), LastMatch as (
		select	LastMatch.EventWrestlerID
				, EventDate = max(cast(event.EventDate as date))
		from	EventWrestlerMatch LastMatch
		join	EventMatch
		on		LastMatch.EventMatchID = EventMatch.ID
		join	event
		on		EventMatch.EventID = event.ID
		where	event.EventDate > getdate() - 720 -- Only wrestlers that have wrestled in the past 2 years
		group by
				LastMatch.EventWrestlerID
)
select	*
into	#DupWrestlers
from	(
		select	WrestlerID = DupWrestler.ID
				, WrestlerName = DupWrestler.WrestlerName
				, FirstName = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, 1, charindex(' ', DupWrestler.WrestlerName) - 1) else DupWrestler.WrestlerName end
				, FirstInitial = substring(DupWrestler.WrestlerName, 1, 1)
				, LastName = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, len(DupWrestler.WrestlerName)) else DupWrestler.WrestlerName end
				, LastInitial = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, 1) else DupWrestler.WrestlerName end
				, Groups = TeamGroup.Groups
				, LastEvent = LastMatch.EventDate
		from	EventWrestler DupWrestler
		join	TeamGroup
		on		DupWrestler.ID = TeamGroup.EventWrestlerID
		join	LastMatch
		on		DupWrestler.ID = LastMatch.EventWrestlerID
		where	len(trim(DupWrestler.WrestlerName)) > 0
		) DupWrestlers
where	len(trim(FirstName)) > 0
		and len(trim(LastName)) > 0;

-- Create indexes on the split parts of the names for faster joining
create index idx_NewWrestlers_FirstNameLastInitial on #NewWrestlers (FirstName, LastInitial);
create index idx_NewWrestlers_LastNameFirstInitial on #NewWrestlers (LastName, FirstInitial);

create index idx_DupWrestlers_FirstNameLastInitial on #DupWrestlers (FirstName, LastInitial);
create index idx_DupWrestlers_LastNameFirstInitial on #DupWrestlers (LastName, FirstInitial);

-- Get the list of matches
select	NewID = PotentialMatches.NewWrestlerID
		, ExistingID = PotentialMatches.ExistingWrestlerID
		, NewWrestler = PotentialMatches.NewWrestler
		, ExistingWrestler = PotentialMatches.ExistingWrestler
		, MatchedTeams = TeamLink.Teams
		, LastEvent = PotentialMatches.LastEvent
into	#Matches
from	(
		select	distinct NewWrestlerID = NewWrestlers.WrestlerID
				, ExistingWrestlerID = DupWrestlers.WrestlerID
				, NewWrestler = NewWrestlers.WrestlerName
				, ExistingWrestler = DupWrestlers.WrestlerName
				, LastEvent = DupWrestlers.LastEvent
				, NewWrestlers.GroupID
		from	#NewWrestlers NewWrestlers
		join	#DupWrestlers DupWrestlers
		on		NewWrestlers.FirstName = DupWrestlers.FirstName
				and NewWrestlers.LastInitial = DupWrestlers.LastInitial
				and NewWrestlers.WrestlerID <> DupWrestlers.WrestlerID
				and DupWrestlers.Groups like '%|' + cast(NewWrestlers.GroupID as varchar(max)) + '|%'
		union
		select	distinct NewWrestlerID = NewWrestlers.WrestlerID
				, ExistingWrestlerID = DupWrestlers.WrestlerID
				, NewWrestler = NewWrestlers.WrestlerName
				, ExistingWrestler = DupWrestlers.WrestlerName
				, LastEvent = DupWrestlers.LastEvent
				, NewWrestlers.GroupID
		from	#NewWrestlers NewWrestlers
		join	#DupWrestlers DupWrestlers
		on		NewWrestlers.LastName = DupWrestlers.LastName 
				and NewWrestlers.FirstInitial = DupWrestlers.FirstInitial
				and NewWrestlers.WrestlerID <> DupWrestlers.WrestlerID
				and DupWrestlers.Groups like '%|' + cast(NewWrestlers.GroupID as varchar(max)) + '|%'
		) PotentialMatches
cross apply (
		select	Teams = string_agg(AllTeams.TeamName, ', ') within group (order by AllTeams.TeamName)
		from	(
				select	TeamGroup.TeamName
						, TeamNumber = row_number() over (order by TeamGroup.TeamName)
		from	#TeamGroup TeamGroup
		where	TeamGroup.GroupID = PotentialMatches.GroupID
				) AllTeams
		where	AllTeams.TeamNumber <= 5
		) TeamLink
order by
		Teams
		, NewWrestler
		, ExistingWrestler;

-- Get the output
select	MatchGroup.MatchGroupID
		, Matches.NewID
		, Matches.ExistingID
		, Matches.NewWrestler
		, Matches.ExistingWrestler
		, Matches.MatchedTeams
		, Matches.LastEvent
from	(
		-- Create a group ID for each group
		select	MatchGroupID = row_number() over (order by NewID)
				, NewID
		from	#Matches
		group by
				NewID
		) MatchGroup
join	#Matches Matches
on		MatchGroup.NewID = Matches.NewID
order by
		MatchedTeams
		, MatchGroupID
		, ExistingID;

set nocount off;