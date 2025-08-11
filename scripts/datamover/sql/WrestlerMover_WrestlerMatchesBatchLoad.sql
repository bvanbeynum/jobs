
with MostCommonTeam as (
	select	EventWrestlerID
			, TeamName
			, TeamRank = row_number() over (partition by EventWrestlerID order by Events desc)
	from	(
			select
				EventWrestlerMatch.EventWrestlerID
				, EventWrestlerMatch.TeamName
				, Events = count(distinct EventMatch.EventID)
			from
				EventWrestlerMatch
			join
				EventMatch
			on	EventWrestlerMatch.EventMatchID = EventMatch.ID
			group by
				EventWrestlerMatch.EventWrestlerID
				, EventWrestlerMatch.TeamName
			) TeamEvents
)
select	EventWrestlerID = EventWrestlerMatch.EventWrestlerID
	, EventID = event.ID
	, EventName = Event.EventName
	, EventDate = Event.EventDate
	, TeamName = Team.TeamName
	, EventState = Event.EventState
	, Division = EventMatch.Division
	, WeightClass = EventMatch.WeightClass
	, MatchRound = EventMatch.RoundName
	, MatchSort = EventMatch.Sort
	, OpponentName = Opponent.WrestlerName
	, OpponentTeamName = OpponentTeam.TeamName
	, OpponentID = OpponentMatch.EventWrestlerID
	, IsWinner = EventWrestlerMatch.IsWinner
	, WinType = EventMatch.WinType
from	EventWrestlerMatch
join	#WrestlerBatch Batch
on		EventWrestlerMatch.EventWrestlerID = Batch.WrestlerID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on
		EventMatch.EventID = Event.ID
left join
		MostCommonTeam Team
on
		EventWrestlerMatch.EventWrestlerID = Team.EventWrestlerID
		and Team.TeamRank = 1
left join
		EventWrestlerMatch OpponentMatch
on
		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and OpponentMatch.EventWrestlerID <> EventWrestlerMatch.EventWrestlerID
left join
		EventWrestler Opponent
on		OpponentMatch.EventWrestlerID = Opponent.ID
left join
		MostCommonTeam OpponentTeam
on
		OpponentMatch.EventWrestlerID = OpponentTeam.EventWrestlerID
		and OpponentTeam.TeamRank = 1
order by	
		Event.EventDate desc
		, MatchSort
