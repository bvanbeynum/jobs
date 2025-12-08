set nocount on;

if object_id('tempdb..#WrestlerLookupMatch') is not null
	drop table #WrestlerLookupMatch;

select	AllWrestlers.SystemID
		, AllWrestlers.WrestlerName
		, AllWrestlers.WrestlerTeam
		, WrestlerLookup.EventWrestlerID
into	#WrestlerLookupMatch
from	(
		select	distinct SystemID = Wrestler1SystemID
				, WrestlerName = Wrestler1Name
				, WrestlerTeam = Wrestler1Team
				, LookupName = replace(trim(Wrestler1Name), ' ', '')
				, LookupTeam = replace(replace(replace(replace(replace(Wrestler1Team, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
		from	#MatchStage
		union
		select	distinct SystemID = Wrestler2SystemID
				, WrestlerName = Wrestler2Name
				, WrestlerTeam = Wrestler2Team
				, LookupName = replace(trim(Wrestler2Name), ' ', '')
				, LookupTeam = replace(replace(replace(replace(replace(Wrestler2Team, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
		from	#MatchStage
		) AllWrestlers
left join
		#WrestlerLookup WrestlerLookup
on		AllWrestlers.LookupName = WrestlerLookup.LookupName
		and AllWrestlers.LookupTeam = WrestlerLookup.LookupTeam;

declare @LastWrestlerID int;

select	@LastWrestlerID = max(id)
from	EventWrestler;

insert	EventWrestler (
			WrestlerName
			, SystemID
		)
select	WrestlerName
		, SystemID
from	#WrestlerLookupMatch WrestlerLookupMatch
where	WrestlerLookupMatch.EventWrestlerID is null;

update	#WrestlerLookupMatch
set		EventWrestlerID = EventWrestler.ID
from	#WrestlerLookupMatch WrestlerLookupMatch
join	EventWrestler
on		WrestlerLookupMatch.SystemID = EventWrestler.SystemID
		and EventWrestler.ID > @LastWrestlerID;

insert	EventMatch (
		EventID
		, Division
		, WeightClass
		, RoundName
		, WinType
		, Sort
		, SystemID
		)
select	MatchStage.EventID
		, MatchStage.DivisionName
		, MatchStage.WeightClassName
		, MatchStage.MatchRound
		, MatchStage.WinType
		, MatchStage.Sort
		, min(MatchStage.SystemID) -- Exclude duplicates
from	#MatchStage MatchStage
left join
		EventMatch
on		MatchStage.EventID = EventMatch.EventID
		and MatchStage.SystemID = EventMatch.SystemID
where	EventMatch.ID is null
group by
		MatchStage.EventID
		, MatchStage.DivisionName
		, MatchStage.WeightClassName
		, MatchStage.MatchRound
		, MatchStage.WinType
		, MatchStage.Sort
		, MatchStage.Wrestler1SystemID -- If same wrestler
		, MatchStage.Wrestler2SystemID;

insert	EventWrestlerMatch (
			EventWrestlerID
			, EventMatchID
			, WrestlerName
			, TeamName
			, IsWinner
		)
select	WrestlerLookupMatch.EventWrestlerID
		, EventMatch.ID
		, WrestlerLookupMatch.WrestlerName
		, WrestlerLookupMatch.WrestlerTeam
		, MatchStage.Wrestler1IsWinner
from	#MatchStage MatchStage
join	EventMatch
on		MatchStage.EventID = EventMatch.EventID
		and MatchStage.SystemID = EventMatch.SystemID
join	#WrestlerLookupMatch WrestlerLookupMatch
on		MatchStage.Wrestler1SystemID = WrestlerLookupMatch.SystemID
union
select	WrestlerLookupMatch.EventWrestlerID
		, EventMatch.ID
		, WrestlerLookupMatch.WrestlerName
		, WrestlerLookupMatch.WrestlerTeam
		, MatchStage.Wrestler2IsWinner
from	#MatchStage MatchStage
join	EventMatch
on		MatchStage.EventID = EventMatch.EventID
		and MatchStage.SystemID = EventMatch.SystemID
join	#WrestlerLookupMatch WrestlerLookupMatch
on		MatchStage.Wrestler2SystemID = WrestlerLookupMatch.SystemID;

set nocount off;
