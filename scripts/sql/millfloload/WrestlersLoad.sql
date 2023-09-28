set nocount on;

select	FloWrestler.ID WrestlerID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, Team = FloWrestler.TeamName
		, Events = count(distinct FloMeet.ID)
		, LastUpdate = max(FloMeet.InsertDate)
into	#wrestlers
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	FloMeet.IsExcluded = 0
		and FloMeet.LocationState = 'sc'
group by
		FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.TeamName;

select	wrestlers.*
		, EventID = FloMeet.ID
		, EventDate = cast(FloMeet.StartTime as date)
		, EventName = FloMeet.MeetName
		, FloMatch.Division
		, FloMatch.WeightClass
		, FloMatch.RoundName
		, FloWrestlerMatch.IsWinner
		, FloMatch.WinType
		, FloMatch.Sort
		, vs = opponent.FirstName + ' ' + opponent.LastName + ' (' + opponent.TeamName + ')'
from	#wrestlers wrestlers
join	FloWrestlerMatch
on		wrestlers.WrestlerID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
join	FloWrestlerMatch vsmatch
on		FloMatch.ID = vsmatch.FloMatchID
		and vsmatch.FloWrestlerID <> wrestlers.WrestlerID
join	FloWrestler opponent
on		vsmatch.FloWrestlerID = opponent.ID
where	FloMeet.IsExcluded = 0
		and FloMeet.StartTime > getdate() - (365 * 2)
order by
		WrestlerID
		, FloMeet.StartTime
		, FloMeet.ID
		, FloMatch.ID;

set nocount off;