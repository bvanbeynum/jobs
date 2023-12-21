
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

declare @OpponentTeam varchar(255)
set @OpponentTeam = 'gilbert'

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
				, Ranking = TSWrestler.Rating
				, Deviation = TSWrestler.Deviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(id) from TSSummary)
		where	TeamLineup.TeamName = 'fort mill'
		) Team
left join
		(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Prediction = TeamLineup.VsFMPredict
				, Ranking = TSWrestler.Rating
				, Deviation = TSWrestler.Deviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(id) from TSSummary)
		where	TeamLineup.TeamName = @OpponentTeam
		) Opponent
on		team.WeightClass = Opponent.WeightClass
order by
		Team.WeightClass
