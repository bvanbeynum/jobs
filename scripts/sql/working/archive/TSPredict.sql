
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

select	*
from	xx_TeamLineup
where	TeamName = 'northwestern'

select	*
from	FloWrestler
where	LastName = 'van beynum'

declare @OpponentTeam varchar(255)
declare @DefaultRank decimal(9,5)

set @OpponentTeam = 'northwestern'
set @DefaultRank = 1500

select	Team.WeightClass
		, Opponent.Wrestler
		, OpponentPrediciton = cast((1.0 / (1.0 + power(10.0, (Team.Mean - Opponent.Mean) / 400.0))) * 100 as int)
		, FMPrediciton = cast((1.0 / (1.0 + power(10.0, (Opponent.Mean - Team.Mean) / 400.0))) * 100 as int)
		, team.Wrestler
from	(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Mean = coalesce(TSWrestler.Mean, @DefaultRank)
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(TSSummaryID) from TSWrestler)
		where	TeamLineup.TeamName = 'fort mill'
		) Team
left join
		(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Mean = coalesce(TSWrestler.Mean, @DefaultRank)
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(TSSummaryID) from TSWrestler)
		where	TeamLineup.TeamName = @OpponentTeam
		) Opponent
on		team.WeightClass = Opponent.WeightClass
order by
		Team.WeightClass
