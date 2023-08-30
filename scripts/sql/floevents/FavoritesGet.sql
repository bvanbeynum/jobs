select	MeetID = FloMeet.ID
		, FloMeet.FlowID
		, FloMeet.MeetName
		, FloMeet.LocationName
		, FloMeet.LocationCity
		, FloMeet.LocationState
		, FloMeet.HasBrackets
		, StartTime = convert(varchar, FloMeet.StartTime, 21)
		, EndTime = convert(varchar, FloMeet.EndTime, 21)
from	FloMeet
where	FloMeet.IsFavorite = 1
		and FloMeet.HasBrackets = 1
		and FloMeet.IsComplete = 0
		and (
			datediff("hh", getdate(), FloMeet.StartTime) < 3 and datediff("ss", coalesce(FloMeet.LastUpdate, getdate() - 365), getdate()) > 90
			or datediff("d", getdate(), FloMeet.StartTime) <= 1 and datediff("ss", coalesce(FloMeet.LastUpdate, getdate() - 365), getdate()) > 300
			or datediff("d", getdate(), FloMeet.StartTime) between 2 and 7 and datediff("hh", coalesce(FloMeet.LastUpdate, getdate() - 365), getdate()) > 1
		);