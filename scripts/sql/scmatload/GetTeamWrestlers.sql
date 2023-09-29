select	FirstName
		, LastName
		, WeightClass
		, Grade
		, Ranking
		, SourceDate
from	WrestlerRank
where	TeamName = ?
order by
		FirstName
		, LastName
		, SourceDate;
