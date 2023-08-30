select	distinct FloMeet.FlowID
from	FloMeet
where	isexcluded = 1
		or iscomplete = 1;