
select	*
from	FloWrestler
where	LastName = 'van beynum'
		-- and FirstName = 'Jackson'
order by
		TeamName

select	*
from	ELORank
where	FloWrestlerID in (7989)

select	Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, EventDate = cast(FloMeet.StartTime as date)
		, EventName = FloMeet.MeetName
		, FloMatch.Division
		, FloMatch.WeightClass
		, FloMatch.RoundName
		, Result = case when FloWrestlerMatch.IsWinner = 1 then 'Beat' else 'Lost to' end +
			' by ' + FloMatch.WinType
		, Vs = vs.FirstName + ' ' + vs.LastName
		, vs.TeamName
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
join	FloWrestlerMatch vsMatch
on		FloWrestlerMatch.FloMatchID = vsMatch.FloMatchID
		and FloWrestlerMatch.FloWrestlerID <> vsMatch.FloWrestlerID
join	FloWrestler vs
on		vsMatch.FloWrestlerID = vs.ID
where	FloWrestler.ID in (96748)
order by
		FloMeet.StartTime
		, FloMatch.MatchNumber
		, FloMatch.Sort
