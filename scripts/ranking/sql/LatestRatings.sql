with LatestRating as (
	select	EventWrestlerID
			, Rating
			, Deviation
			, JVRating
			, JVDeviation
			, MSRating
			, MSDeviation
			, GirlsRating
			, GirlsDeviation
			, RowNum = row_number() over(partition by EventWrestlerID order by PeriodEndDate desc)
	from	WrestlerRating
)
select	EventWrestlerID
		, Rating
		, Deviation
		, JVRating
		, JVDeviation
		, MSRating
		, MSDeviation
		, GirlsRating
		, GirlsDeviation
from	LatestRating
where	RowNum = 1;
