select	MatchID = FloMatch.ID
		, MatchGUID = FloMatch.FlowID
		, Division = FloMatch.Division
		, WeightClass = FloMatch.WeightClass
		, Round = FloMatch.RoundName
		, MatchNumber = case when FloMatch.MatchNumber is not null then FloMatch.MatchNumber else '' end
		, Mat = FloMatch.Mat
		, WinType = FloMatch.WinType
		, TopGUID = TopWrestler.FlowID
		, TopWrestler = TopWrestler.FirstName + ' ' + TopWrestler.LastName
		, TopTeam = TopWrestler.TeamName
		, BottomGUID = BottomWrestler.FlowID
		, BottomWrestler = BottomWrestler.FirstName + ' ' + BottomWrestler.LastName
		, BottomTeam = BottomWrestler.TeamName
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
left join
		FloWrestler TopWrestler
on		FloMatch.TopFlowWrestlerID = TopWrestler.ID
left join
		FloWrestler BottomWrestler
on		FloMatch.BottomFlowWrestlerID = BottomWrestler.ID
where	FloMeet.ID = ?
order by
		FloMatch.Sort;