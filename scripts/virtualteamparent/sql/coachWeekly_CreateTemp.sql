create table #WeekEvents (
	EventID int
	, EventDate date
	, EventName varchar(255)
	, SchoolID int
	, SchoolName varchar(255)
	, EventSchoolName varchar(255)
);

create table #EventRatings (
	EventID int
	, EventName varchar(255)
	, SchoolID int
	, Division varchar(255)
	, WeightClass varchar(255)
	, EventWrestlerID int
	, Rating int
);
