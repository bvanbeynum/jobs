set nocount on;
declare @output int;
exec dbo.WrestlerMatchSave @WrestlerMatchID = @output output
	, @WrestlerID = ?
	, @MatchID = ?
	, @IsWinner = ?
	, @Team = ?;
select @output as OutputValue;