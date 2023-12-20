set nocount on;

update	TSWrestler
set		Rating = Stage.Rating
		, Deviation = Stage.Deviation
		, Volatility = Stage.Volatility
		, ModifiedDate = getdate()
from	TSWrestler
join	#TSWrestler_stage Stage
on		TSWrestler.ID = Stage.TSWrestlerID;

update	TSMatch
set		WinProbability = Stage.WinProbability
		, RatingInitial = Stage.RatingInitial
		, DeviationInitial = Stage.DeviationInitial
		, VolatilityInitial = Stage.VolatilityInitial
		, RatingUpdate = Stage.RatingUpdate
		, DeviationUpdate = Stage.DeviationUpdate
		, VolatilityUpdate = Stage.VolatilityUpdate
		, ModifiedDate = getdate()
from	TSMatch
join	#TSMatch_stage Stage
on		TSMatch.ID = Stage.TSMatchID;

set nocount off;