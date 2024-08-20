select	FlowID
		, MeetName
		, StartTime
		, LocationName
from	FloMeet
where	StartTime > getdate();