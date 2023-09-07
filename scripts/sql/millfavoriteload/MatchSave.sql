set nocount on;
declare @output int;
exec dbo.MatchSave @MatchID = @output output
	, @MeetID = ?
	, @FlowID = ?
	, @Division = ?
	, @WeightClass = ?
	, @PoolName = ?
	, @RoundName = ?
	, @WinType = ?
	, @VideoURL = ?
	, @Sort = ?
	, @MatchNumber = ?
	, @Mat = ?
	, @Results = ?
	, @TopFlowWrestlerID = ?
	, @BottomFlowWrestlerID = ?
	, @WinnerMatchFlowID = ?
	, @WinnerToTop = ?
	, @LoserMatchFlowID = ?
	, @LoserToTop = ?
	, @WinnerWrestlerID = ?
	, @RoundNumber = ?
	, @RoundSpot = ?;
select @output as OutputValue;