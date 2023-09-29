select	TeamRank.Confrence
		, TeamRank.TeamName
		, TeamRank.Ranking
		, TeamRank.SourceDate
from	TeamRank
order by
		TeamRank.TeamName
		, TeamRank.SourceDate;
