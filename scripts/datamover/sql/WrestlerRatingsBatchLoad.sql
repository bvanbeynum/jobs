select	WrestlerRating.EventWrestlerID,
		WrestlerRating.PeriodEndDate,
		WrestlerRating.Rating,
		WrestlerRating.Deviation
from	WrestlerRating
join 	#WrestlerBatch WB 
on		WrestlerRating.EventWrestlerID = WB.WrestlerID
where	(
			getdate() >= cast(cast(year(getdate()) as varchar(255)) + '-12-01' as date)
			and WrestlerRating.PeriodEndDate > cast(cast(year(getdate()) as varchar(255)) + '-11-01' as date)
		)
		or (
			getdate() < cast(cast(year(getdate()) as varchar(255)) + '-12-01' as date)
			and WrestlerRating.PeriodEndDate > cast(cast(year(getdate()) - 1 as varchar(255)) + '-11-01' as date)
		)
