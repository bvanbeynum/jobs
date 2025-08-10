select	MatchID = FloMatch.ID
		, WinnerID = Winner.ID
		, Winner = Winner.FirstName + ' ' + Winner.LastName
		, WinnerTeam = Winner.TeamName
		, LoserID = Loser.ID
		, Loser = Loser.FirstName + ' ' + Loser.LastName
		, LoserTeam = Loser.TeamName
		, WinType = FloMatch.WinType
		, EventDate = cast(FloMeet.StartTime as date)
		, EventName = FloMeet.MeetName
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
join	FloWrestlerMatch WinnerMatch
on		FloMatch.ID = WinnerMatch.FloMatchID
		and WinnerMatch.IsWinner = 1
join	FloWrestler Winner
on		WinnerMatch.FloWrestlerID = winner.ID
join	FloWrestlerMatch LoserMatch
on		FloMatch.ID = LoserMatch.FloMatchID
		and LoserMatch.IsWinner = 0
join	FloWrestler Loser
on		LoserMatch.FloWrestlerID = Loser.ID
where	FloMeet.IsComplete = 1
order by
		FloMeet.ID desc;