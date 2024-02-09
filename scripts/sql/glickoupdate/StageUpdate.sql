set nocount on;

declare @SummaryID int;

set @SummaryID = 51;

update	TSWrestler
set		Rating = UpdateData.Rating
		, Deviation = UpdateData.Deviation
		, Volatility = UpdateData.Volatility
		, ModifiedDate = getdate()
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
set		WinProbability = UpdateData.WinProbability
		, RatingUpdate = UpdateData.Rating
		, DeviationUpdate = UpdateData.Deviation
		, VolatilityUpdate = UpdateData.Volatility
		, ModifiedDate = getdate()
from	TSMatch
join	(
		select	TSMatchID
				, WinProbability
				, Rating
				, Deviation
				, Volatility
		from	#TSStage
		where	TSMatchID is not null
		) UpdateData
on		TSMatch.ID = UpdateData.TSMatchID;

update	TSSummary
set		ModifiedDate = getdate()
		, RunDate = getdate()
where	ID = @SummaryID;

set nocount off;