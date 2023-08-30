set nocount on;
declare @output int;
exec dbo.WrestlerSave @WrestlerID = @output output
	, @FlowID = ?
	, @FirstName = ?
	, @LastName = ?
	, @TeamName = ?
	, @TeamFlowID = ?;
select @output as OutputValue;