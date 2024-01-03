set nocount on;

update	TSWrestler
set		Rating = UpdateData.Rating
		, Deviation = UpdateData.Deviation
		, Volatility = UpdateData.Volatility
from	TSWrestler
join	(
		select	distinct TSWrestlerID
				, Rating
				, Deviation
				, Volatility
		from	#TSStage
		) UpdateData
on		TSWrestler.ID = UpdateData.TSWrestlerID;

update	TSMatch
set		RatingUpdate = UpdateData.Rating
		, DeviationUpdate = UpdateData.Deviation
		, VolatilityUpdate = UpdateData.Volatility
from	TSMatch
join	(
		select	TSMatchID
				, Rating
				, Deviation
				, Volatility
		from	#TSStage
		where	TSMatchID is not null
		) UpdateData
on		TSMatch.ID = UpdateData.TSMatchID;

set nocount off;