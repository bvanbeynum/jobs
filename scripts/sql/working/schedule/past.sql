
select	EventID = TrackEvent.ID
		, TrackEvent.EventDate
		, [Month] = datepart(month, TrackEvent.EventDate)
		, [Week] = datepart(week, TrackEvent.EventDate)
		, [Length] = coalesce(datediff(d, TrackEvent.EventDate, TrackEvent.EndDate), 0) + 1
		, TrackEvent.EventName
		, TrackEvent.EventState
		, DivisionCount = count(distinct TrackMatch.Division)
		, LargestDivision.Division
		, Teams = count(distinct TrackWrestlerMatch.Team)
		, Wrestlers = count(distinct TrackWrestlerMatch.TrackWrestlerID)
		, [URL] = 'https://www.trackwrestling.com/tw/' + TrackEvent.EventType + '/VerifyPassword.jsp?tournamentId=' + cast(TrackEvent.EventID as varchar(max))
		, EventType = 'Track'
from	TrackEvent
join	TrackMatch
on		TrackEvent.ID = TrackMatch.TrackEventID
join	TrackWrestlerMatch
on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
outer apply (
		select	top 1 Division = coalesce(DivisionMatch.Division, 'N/A') + ': ' + cast(count(distinct DivisionWrestler.TrackWrestlerID) as varchar(max))
		from	TrackMatch DivisionMatch
		join	TrackWrestlerMatch DivisionWrestler
		on		DivisionMatch.ID = DivisionWrestler.TrackMatchID
		where	TrackEvent.ID = DivisionMatch.TrackEventID
		group by
				DivisionMatch.Division
		order by
				count(distinct DivisionWrestler.TrackWrestlerID)
		) LargestDivision
where	TrackEvent.EventDate between '1/1/2024' and '1/1/2025'
group by
		TrackEvent.EventDate
		, TrackEvent.EndDate
		, TrackEvent.EventName
		, TrackEvent.EventState
		, LargestDivision.Division
		, TrackEvent.EventType
		, TrackEvent.EventID
		, TrackEvent.ID
union
select	EventID = FloMeet.ID
		, EventDate = cast(FloMeet.StartTime as date)
		, [Month] = datepart(month, FloMeet.StartTime)
		, [Week] = datepart(week, FloMeet.StartTime)
		, [Length] = coalesce(datediff(d, FloMeet.StartTime, FloMeet.EndTime), 0) + 1
		, FloMeet.MeetName
		, FloMeet.LocationState
		, DivisionCount = count(distinct FloMatch.Division)
		, LargestDivision.Division
		, Teams = count(distinct FloWrestlerMatch.Team)
		, Wrestlers = count(distinct FloWrestlerMatch.FloWrestlerID)
		, [URL] = 'https://arena.flowrestling.org/event/' + FloMeet.FlowID
		, EventType = 'Flo'
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
outer apply (
		select	top 1 Division = coalesce(DivisionMatch.Division, '') + ': ' + cast(count(distinct DivisionWrestler.FloWrestlerID) as varchar(max))
		from	FloMatch DivisionMatch
		join	FloWrestlerMatch DivisionWrestler
		on		DivisionMatch.ID = DivisionWrestler.FloMatchID
		where	FloMeet.ID = DivisionMatch.FloMeetID
		group by
				DivisionMatch.Division
		order by
				count(distinct DivisionWrestler.FloWrestlerID)
		) LargestDivision
where	FloMeet.StartTime between '1/1/2024' and '1/1/2025'
group by
		FloMeet.StartTime
		, FloMeet.EndTime
		, FloMeet.MeetName
		, FloMeet.LocationState
		, LargestDivision.Division
		, FloMeet.FlowID
		, FloMeet.ID

order by
		EventDate
