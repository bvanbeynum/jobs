select	EventWrestlerID = EventWrestlerMatch.EventWrestlerID
		, EventID = event.ID
		, EventName = Event.EventName
		, EventDate = Event.EventDate
		, TeamName = coalesce(SchoolLookup.SchoolName, EventWrestlerMatch.TeamName)
		, EventState = Event.EventState
		, Division = EventMatch.Division
		, WeightClass = trim(replace(EventMatch.WeightClass, 'lbs', ''))
		, MatchRound = EventMatch.RoundName
		, MatchSort = EventMatch.Sort
		, OpponentName = Opponent.WrestlerName
		, OpponentTeamName = OpponentMatch.TeamName
		, OpponentID = OpponentMatch.EventWrestlerID
		, OpponentRating = OpponentRating.Rating
		, OpponentDeviation = OpponentRating.Deviation
		, IsWinner = EventWrestlerMatch.IsWinner
		, WinType = EventMatch.WinType
from	EventWrestlerMatch
join	#WrestlerBatch Batch
on		EventWrestlerMatch.EventWrestlerID = Batch.WrestlerID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
left join
		EventWrestlerMatch OpponentMatch
on		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and OpponentMatch.EventWrestlerID <> EventWrestlerMatch.EventWrestlerID
left join
		EventWrestler Opponent
on		OpponentMatch.EventWrestlerID = Opponent.ID
outer apply (
		select	distinct School.SchoolName
		from	EventSchool
		join	School
		on		EventSchool.SchoolID = School.ID
		where	EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
		) SchoolLookup
outer apply (
		select	top 1 WrestlerRating.Rating
				, WrestlerRating.Deviation
		from	WrestlerRating
		where	OpponentMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WrestlerRating.PeriodEndDate < event.EventDate
		order by
				WrestlerRating.PeriodEndDate desc
		) OpponentRating
order by	
		Event.EventDate desc
		, MatchSort
