set nocount on;

declare @Confrence varchar(255);
declare @FirstName varchar(255);
declare @LastName varchar(255);
declare @TeamName varchar(255);
declare @WeightClass varchar(255);
declare @Ranking int;
declare @Grade varchar(255);
declare @SourceDate date;

set @Confrence = ?;
set @FirstName = ?;
set @LastName = ?;
set @TeamName = ?;
set @WeightClass = ?;
set @Ranking = ?;
set @Grade = ?;
set @SourceDate = ?;

insert	WrestlerRank (
		Confrence
		, FirstName
		, LastName
		, TeamName
		, WeightClass
		, Ranking
		, Grade
		, SourceDate
	)
values	(
		@Confrence
		, @FirstName
		, @LastName
		, @TeamName
		, @WeightClass
		, @Ranking
		, @Grade
		, @SourceDate
	);

set nocount off;
