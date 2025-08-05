select	SystemID
		, EventName
		, EventDate
		, EventAddress
from	Event
where	EventSystem = 'Flo'
		and EventDate > getdate();