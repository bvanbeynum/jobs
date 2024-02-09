
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

declare @OpponentTeam varchar(255)
declare @DefaultRank decimal(9,5)

set @OpponentTeam = 'river bluff'
set @DefaultRank = 1500

select	Team.WeightClass
		, Opponent.Wrestler
		, OpponentPrediciton = cast((1.0 / (1.0 + power(10.0, (Team.ELO - Opponent.ELO) / 400.0))) * 100 as int)
		, FMPrediciton = cast((1.0 / (1.0 + power(10.0, (Opponent.ELO - Team.ELO) / 400.0))) * 100 as int)
		, team.Wrestler
from	(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, ELO = coalesce(ELORank.Ranking, @DefaultRank)
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				ELORank
		on		FloWrestler.ID = ELORank.FloWrestlerID
				and ELORank.ELOSummaryID = (select max(ELOSummaryID) from ELORank)
		where	TeamLineup.TeamName = 'fort mill'
		) Team
left join
		(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, ELO = coalesce(ELORank.Ranking, @DefaultRank)
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				ELORank
		on		FloWrestler.ID = ELORank.FloWrestlerID
				and ELORank.ELOSummaryID = (select max(ELOSummaryID) from ELORank)
		where	TeamLineup.TeamName = @OpponentTeam
		) Opponent
on		team.WeightClass = Opponent.WeightClass
order by
		Team.WeightClass
