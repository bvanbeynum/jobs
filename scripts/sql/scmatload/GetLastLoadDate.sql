select	TeamDate = cast(team.LastLoad as datetime)
		, WrestlerDate = cast(Wrestler.LastLoad as datetime)
from	(
		select	LastLoad = max(SourceDate)
		from	TeamRank
		) Team,
		(
		select	LastLoad = max(SourceDate)
		from	WrestlerRank
		) Wrestler;
