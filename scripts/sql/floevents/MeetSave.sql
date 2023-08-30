set nocount on;
declare @output int;
exec dbo.MeetSave @MeetID = @output output
	, @FlowID = ?
	, @MeetName = ?
	, @IsExcluded = ?
	, @IsComplete = ?
	, @LocationName = ?
	, @LocationCity = ?
	, @LocationState = ?
	, @StartTime = ?
	, @EndTime = ?
	, @HasBrackets = ?;
select @output as OutputValue;