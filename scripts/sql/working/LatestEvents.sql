
declare @LastWeek date;

select	@LastWeek = dateadd(day, -7, getdate());

select	*
from	(
		select	EventDate = cast(FloMeet.StartTime as date)
				, EventSystem = cast('Flo' as varchar(max))
				, EventName = FloMeet.MeetName
				, [State] = FloMeet.LocationState
				, [Location] = FloMeet.LocationName
				, Teams = count(distinct FloWrestlerMatch.Team)
				, Wrestlers = count(distinct FloWrestlerMatch.FloWrestlerID)
				, Divisions = count(distinct FloMatch.Division)
				, WeightClasses = count(distinct FloMatch.WeightClass)
				, Matches = count(distinct case when FloWrestlerMatch.IsWinner = 1 then FloMatch.ID else null end)
		from	FloMeet
		join	FloMatch
		on		FloMeet.ID = FloMatch.FloMeetID
		join	FloWrestlerMatch
		on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		where	coalesce(FloMeet.endtime, FloMeet.StartTime) > @LastWeek
				and FloMeet.isexcluded = 0
				and FloMeet.IsComplete = 1
		group by
				cast(FloMeet.StartTime as date)
				, FloMeet.MeetName
				, FloMeet.LocationName
				, FloMeet.LocationState

		union

		select	EventDate = cast(TrackEvent.EventDate as date)
				, EventSystem = cast('Track' as varchar(max))
				, EventName = TrackEvent.EventName
				, [State] = TrackEvent.EventState
				, [Location] = TrackEvent.EventAddress
				, Teams = count(distinct TrackWrestlerMatch.Team)
				, Wrestlers = count(distinct TrackWrestlerMatch.TrackWrestlerID)
				, Divisions = count(distinct TrackMatch.Division)
				, WeightClasses = count(distinct TrackMatch.WeightClass)
				, Matches = count(distinct case when TrackWrestlerMatch.IsWinner = 1 then TrackMatch.ID else null end)
		from	TrackEvent
		join	TrackMatch
		on		TrackEvent.ID = TrackMatch.TrackEventID
		join	TrackWrestlerMatch
		on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
		where	TrackEvent.EventDate > @LastWeek
				and TrackEvent.IsComplete = 1
		group by
				cast(TrackEvent.EventDate as date)
				, TrackEvent.EventName
				, TrackEvent.EventAddress
				, TrackEvent.EventState
		) AllEvents
order by
		EventDate desc
		, [State]
		, [Location]
		, EventName
