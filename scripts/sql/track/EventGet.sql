select	TrackEvent.ID TrackID
		, TrackEvent.IsComplete
from	TrackEvent
where	TrackEvent.EventID = ?;