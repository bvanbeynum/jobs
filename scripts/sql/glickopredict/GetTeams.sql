set nocount on;

select	TeamID = team.ID
		, team.TeamName
		, team.WeightClass
		, OpponentMean = TSWrestler.Rating
		, OpponentSD = TSWrestler.Deviation
		, OpponentVolatility = TSWrestler.Volatility
		, FMMean = FMRank.Rating
		, FMSD = FMRank.Deviation
		, FMVolatility = FMRank.Volatility
from	xx_TeamLineup team
left join
		TSWrestler
on		team.FloWrestlerID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = (select max(ID) from TSSummary)
left join
		xx_TeamLineup FortMill
on		team.WeightClass = FortMill.WeightClass
		and FortMill.TeamName = 'fort mill'
left join
		TSWrestler FMRank
on		FortMill.FloWrestlerID = FMRank.FloWrestlerID
		and FMRank.TSSummaryID = (select max(ID) from TSSummary)
where	team.TeamName <> 'fort mill'
		and TSWrestler.Rating is not null
		and FMRank.Rating is not null
order by
		team.TeamName
		, team.WeightClass

set nocount off;
