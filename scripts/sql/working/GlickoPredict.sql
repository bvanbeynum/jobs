
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

declare @OpponentTeam varchar(255)
set @OpponentTeam = 'rock hill'

select	Team.WeightClass
		, Opponent.Wrestler
		, OpponentPrediciton = round(Opponent.Prediction * 100, 2)
		, FMPrediciton = round((1 - Opponent.Prediction) * 100, 2)
		, team.Wrestler
		, FMRank = team.Ranking
		, FMDeviation = team.Deviation
		, OpponentRank = Opponent.Ranking
		, OpponentDeviation = Opponent.Deviation
from	(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Ranking = FloWrestler.GRating
				, Deviation = FloWrestler.GDeviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = 51
		where	TeamLineup.TeamName = 'fort mill'
		) Team
left join
		(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Prediction = TeamLineup.VsFMPredict
				, Ranking = FloWrestler.GRating
				, Deviation = FloWrestler.GDeviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = 51
		where	TeamLineup.TeamName = @OpponentTeam
		) Opponent
on		team.WeightClass = Opponent.WeightClass
order by
		Team.WeightClass

select	WeightClass
		, Wrestler
		, EventDate
		, [Event]
		, Division
		, EventWeight
		, RoundName
		, Result
		, Vs
		, Team
		, WinType
from	(
		select	TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName + ' (' + cast(cast(coalesce(FloWrestler.GRating, 1500) as int) as varchar(max)) + ')'
				, EventDate = cast(FloMeet.StartTime as date)
				, [Event] = FloMeet.MeetName
				, FloMatch.Division
				, EventWeight = FloMatch.WeightClass
				, FloMatch.RoundName
				, Result = case when FloWrestlerMatch.IsWinner = 1 then 'Beat' else 'Lost To' end
				, Vs = Opponent.FirstName + ' ' + Opponent.LastName + ' (' + cast(cast(Opponent.GRating as int) as varchar(max)) + ')'
				, Team = Opponent.TeamName
				, FloMatch.WinType
				, FloMatch.Sort
				, MatchID = FloMatch.ID
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		join	FloWrestlerMatch OpponentMatch
		on		FloWrestlerMatch.FloMatchID = OpponentMatch.FloMatchID
				and FloWrestlerMatch.FloWrestlerID <> OpponentMatch.FloWrestlerID
		join	FloWrestler Opponent
		on		OpponentMatch.FloWrestlerID = Opponent.ID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				and FloMatch.WinType is not null
				and FloMatch.WinType <> 'bye'
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	TeamLineup.TeamName = @OpponentTeam
		union all
		select	TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName + ' (' + cast(cast(FloWrestler.GRating as int) as varchar(max)) + ')'
				, EventDate = cast(TrackEvent.EventDate as date)
				, [Event] = TrackEvent.EventName
				, TrackMatch.Division
				, EventWeight = TrackMatch.WeightClass
				, TrackMatch.RoundName
				, Result = case when TrackWrestlerMatch.IsWinner = 1 then 'Beat' else 'Lost To' end
				, Vs = Opponent.WrestlerName
				, Team = Opponent.TeamName
				, TrackMatch.WinType
				, TrackMatch.Sort
				, MatchID = TrackMatch.ID
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		join	TrackWrestler
		on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		join	TrackWrestlerMatch OpponentMatch
		on		TrackWrestlerMatch.TrackMatchID = OpponentMatch.TrackMatchID
				and TrackWrestlerMatch.TrackWrestlerID <> OpponentMatch.TrackWrestlerID
		join	TrackWrestler Opponent
		on		OpponentMatch.TrackWrestlerID = Opponent.ID
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TeamLineup.TeamName = @OpponentTeam
				and TrackMatch.WinType is not null
				and TrackMatch.WinType <> 'bye'
		) Events
order by
		WeightClass
		, eventdate desc
		, Sort desc
