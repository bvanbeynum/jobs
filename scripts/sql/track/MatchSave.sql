set nocount on;

declare @TrackEventID int;
declare @Division varchar(255);
declare @WeightClass varchar(255);
declare @RoundName varchar(255);
declare @WinType varchar(255);
declare @Sort int;

set @TrackEventID = ?;
set @Division = ?;
set @WeightClass = ?;
set @RoundName = ?;
set @WinType = ?;
set @Sort = ?;

insert	TrackMatch (
		TrackEventID
		, Division
		, WeightClass
		, RoundName
		, WinType
		, Sort
		)
values	(
		@TrackEventID
		, @Division
		, @WeightClass
		, @RoundName
		, @WinType
		, @Sort
		);

select	scope_identity();

set nocount off;