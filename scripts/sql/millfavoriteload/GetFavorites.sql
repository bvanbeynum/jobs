select	FloMeet.ID
		, FloMeet.FlowID
		, FloMeet.MeetName
		, FloMeet.StartTime
		, FloMeet.EndTime
		, FloMeet.LastUpdate
from	FloMeet
where	FloMeet.IsFavorite = 1
		and (FloMeet.IsComplete = 0 or FloMeet.LastUpdate is null)
		and FloMeet.IsExcluded = 0
order by
		FloMeet.StartTime;