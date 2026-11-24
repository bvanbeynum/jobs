set nocount on;

declare @TimespanDays int = ?;
declare @CutoffDate datetime = dateadd(day, @TimespanDays, getdate());

if object_id('tempdb..#ModifiedWrestlerEvents') is not null
	drop table #ModifiedWrestlerEvents;

select distinct
		WrestlerID = EventWrestlerMatch.EventWrestlerID,
		EventID = Event.ID
into	#ModifiedWrestlerEvents
from	#WrestlerEventsBatch Batch
join	EventWrestlerMatch
on		EventWrestlerMatch.EventWrestlerID = Batch.WrestlerID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
left join
		EventWrestlerMatch OpponentMatch
on		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and OpponentMatch.EventWrestlerID <> EventWrestlerMatch.EventWrestlerID
where	Event.EventSystem <> 'WrestlingPortal'
		and (
			Batch.FullSync = 1
			or Event.ModifiedDate >= @CutoffDate
			or EventMatch.ModifiedDate >= @CutoffDate
			or EventWrestlerMatch.ModifiedDate >= @CutoffDate
			or OpponentMatch.ModifiedDate >= @CutoffDate
		);

create clustered index ix_ModifiedWrestlerEvents on #ModifiedWrestlerEvents (WrestlerID, EventID);

select	WrestlerID = EventWrestlerMatch.EventWrestlerID
		, EventID = event.ID
		, Event.EventSystem
		, SystemID = Event.SystemID
		, EventName = Event.EventName
		, EventDate = Event.EventDate
		, TeamName = coalesce(WrestlerSchool.SchoolName, EventWrestlerMatch.TeamName)
		, EventState = Event.EventState
		, Division = EventMatch.Division
		, WeightClass = trim(replace(EventMatch.WeightClass, 'lbs', ''))
		, Seed = min(EventWrestlerMatch.Seed) over (partition by EventWrestlerMatch.EventWrestlerID, event.ID)
		, MatchSQLID = EventMatch.ID
		, MatchRound = EventMatch.RoundName
		, EventMatch.VideoURL
		, MatchSort = EventMatch.Sort
		, OpponentName = Opponent.WrestlerName
		, OpponentTeamName = coalesce(OpponentSchool.SchoolName, OpponentMatch.TeamName)
		, OpponentID = OpponentMatch.EventWrestlerID
		, OpponentRating = OpponentRating.Rating
		, OpponentDeviation = OpponentRating.Deviation
		, IsWinner = EventWrestlerMatch.IsWinner
		, WinType = EventMatch.WinType
		, EventWrestlerMatch.Takedowns
		, EventWrestlerMatch.Escapes
		, EventWrestlerMatch.Nearfalls
		, EventWrestlerMatch.Reversals
from	EventWrestlerMatch
join	#ModifiedWrestlerEvents ModifiedEvents
on		EventWrestlerMatch.EventWrestlerID = ModifiedEvents.WrestlerID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		and EventMatch.EventID = ModifiedEvents.EventID
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
				and Event.EventState = 'sc'
		) WrestlerSchool
outer apply (
		select	distinct School.SchoolName
		from	EventSchool
		join	School
		on		EventSchool.SchoolID = School.ID
		where	OpponentMatch.TeamName = EventSchool.EventSchoolName
				and Event.EventState = 'sc'
		) OpponentSchool
outer apply (
		select	top 1 WrestlerRating.Rating
				, WrestlerRating.Deviation
		from	WrestlerRating
		where	OpponentMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WrestlerRating.PeriodEndDate < event.EventDate
		order by
				WrestlerRating.PeriodEndDate desc
		) OpponentRating
where	Event.EventSystem <> 'WrestlingPortal'
order by	
		Event.EventDate desc
		, MatchSort;

set nocount off;
