set nocount on;

declare @TeamID int;
declare @Prediction decimal(18,9);

set @TeamID = ?;
set @Prediction = ?;

update	xx_TeamLineup
set		VsFMPredict = @Prediction
where	id = @TeamID;

set nocount off;
