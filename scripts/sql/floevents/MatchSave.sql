set nocount on;

declare @EventID int;
declare @Division varchar(255);
declare @WeightClass varchar(255);
declare @RoundName varchar(255);
declare @WinType varchar(255);
declare @Sort int;

set @EventID = ?;
set @Division = ?;
set @WeightClass = ?;
set @RoundName = ?;
set @WinType = ?;
set @Sort = ?;

insert	EventMatch (
		EventID
		, Division
		, WeightClass
		, RoundName
		, WinType
		, Sort
		)
values	(
		@EventID
		, @Division
		, @WeightClass
		, @RoundName
		, @WinType
		, @Sort
		);

select	scope_identity();

set nocount off;
