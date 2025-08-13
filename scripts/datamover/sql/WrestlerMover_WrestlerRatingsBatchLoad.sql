
SELECT
	WR.EventWrestlerID,
	WR.PeriodEndDate,
	WR.Rating,
	WR.Deviation
FROM WrestlerRating WR
JOIN #WrestlerBatch WB ON WR.EventWrestlerID = WB.WrestlerID
