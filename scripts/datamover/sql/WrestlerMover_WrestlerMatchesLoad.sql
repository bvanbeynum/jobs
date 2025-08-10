with MostCommonTeamPerEvent as (
	select
		EventID,
		TeamID,
		row_number() over (partition by EventID order by count(*) desc) as TeamRank
	from
		EventWrestlerMatch
	where
		WrestlerID = ?
	group by
		EventID,
		TeamID
)
select	EventID = EventWrestlerMatch.EventID
	, EventName = Event.EventName
	, EventDate = Event.EventDate
	, TeamName = Team.TeamName
	, EventState = Event.State
	, WeightClass = EventWrestlerMatch.WeightClass
	, MatchRound = EventWrestlerMatch.MatchRound
	, OpponentName = EventWrestlerMatch.OpponentName
	, OpponentTeamName = OpponentTeam.TeamName
	, OpponentID = EventWrestlerMatch.OpponentID
	, IsWinner = EventWrestlerMatch.IsWinner
	, WinType = EventWrestlerMatch.WinType
from	EventWrestlerMatch
join	Event
on
		Event.ID = EventWrestlerMatch.EventID
join	MostCommonTeamPerEvent
on
		MostCommonTeamPerEvent.EventID = EventWrestlerMatch.EventID
		and MostCommonTeamPerEvent.TeamRank = 1
join	Team
on
		Team.ID = MostCommonTeamPerEvent.TeamID
join	Team as OpponentTeam
on
		OpponentTeam.ID = EventWrestlerMatch.OpponentTeamID
where	EventWrestlerMatch.WrestlerID = ?
order by	Event.EventDate desc