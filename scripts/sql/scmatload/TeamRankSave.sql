set nocount on;

declare @Confrence varchar(255);
declare @TeamName varchar(255);
declare @Ranking int;
declare @SourceDate date;

set @Confrence = ?;
set @TeamName = ?;
set @Ranking = ?;
set @SourceDate = ?;

insert	TeamRank (
		Confrence
		, TeamName
		, Ranking
		, SourceDate
	)
values	(
		@Confrence
		, @TeamName
		, @Ranking
		, @SourceDate
	);

set nocount off;
