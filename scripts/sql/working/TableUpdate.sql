return;

create table dbo.TSMatch_tmp (
	ID int not null
	, TSWrestlerID int not null
	, IsFlo bit not null
	, EventID int null
	, MatchID int not null
	, IsWinner bit null
	, WinProbability decimal(18,9) null
	, RatingInitial decimal(18,9) null
	, DeviationInitial decimal(18,9) null
	, VolatilityInitial decimal(18,9) null
	, RatingUpdate decimal(18,9) null
	, DeviationUpdate decimal(18,9) null
	, VolatilityUpdate decimal(18,9) null
	, Sort int not null
	, InsertDate datetime not null
	, ModifiedDate datetime not null
);

insert	TSMatch_tmp (
		ID
		, TSWrestlerID
		, IsFlo
		, EventID
		, MatchID
		, IsWinner
		, WinProbability
		, RatingInitial
		, DeviationInitial
		, VolatilityInitial
		, RatingUpdate
		, DeviationUpdate
		, VolatilityUpdate
		, Sort
		, InsertDate
		, ModifiedDate
		)
select	ID
		, TSWrestlerID
		, IsFlo
		, EventID
		, MatchID
		, IsWinner
		, WinProbability
		, RatingInitial
		, DeviationInitial
		, VolatilityInitial
		, RatingUpdate
		, DeviationUpdate
		, VolatilityUpdate
		, Sort
		, InsertDate
		, ModifiedDate
from	TSMatch;

select count(0) from TSMatch;
select count(0) from TSMatch_tmp;

drop table TSMatch;

create table dbo.TSMatch (
	ID int identity(1,1) not null primary key
	, TSWrestlerID int not null
	, IsFlo bit not null
	, EventID int null
	, MatchID int not null
	, IsWinner bit null
	, WinProbability decimal(18,9) null
	, RatingInitial decimal(18,9) null
	, DeviationInitial decimal(18,9) null
	, VolatilityInitial decimal(18,9) null
	, RatingUpdate decimal(18,9) null
	, DeviationUpdate decimal(18,9) null
	, VolatilityUpdate decimal(18,9) null
	, Sort int not null
	, InsertDate datetime not null default getdate()
	, ModifiedDate datetime not null default getdate()
);

set identity_insert TSMatch on;

insert	TSMatch (
		ID
		, TSWrestlerID
		, IsFlo
		, EventID
		, MatchID
		, IsWinner
		, WinProbability
		, RatingInitial
		, DeviationInitial
		, VolatilityInitial
		, RatingUpdate
		, DeviationUpdate
		, VolatilityUpdate
		, Sort
		, InsertDate
		, ModifiedDate
		)
select	ID
		, TSWrestlerID
		, IsFlo
		, EventID
		, MatchID
		, IsWinner
		, WinProbability
		, RatingInitial
		, DeviationInitial
		, VolatilityInitial
		, RatingUpdate
		, DeviationUpdate
		, VolatilityUpdate
		, Sort
		, InsertDate
		, ModifiedDate
from	TSMatch_tmp;

set identity_insert TSMatch off;

select count(0) from TSMatch;
select count(0) from TSMatch_tmp;
select top 100 * from TSMatch order by newid();

-- *********** Wrestler

create table dbo.TSWrestler_tmp (
	ID int not null
	, TSSummaryID int not null
	, FloWrestlerID int null
	, TrackWrestlerID int null
	, Mean decimal(18,9) not null
	, StandardDeviation decimal(18,9) not null
	, Volatility decimal(18,9) not null
	, InsertDate datetime not null
	, ModifiedDate datetime not null
);

insert	TSWrestler_tmp (
		ID
		, TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Mean
		, StandardDeviation
		, Volatility
		, InsertDate
		, ModifiedDate
		)
select	ID
		, TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Mean
		, StandardDeviation
		, Volatility
		, InsertDate
		, ModifiedDate
from	TSWrestler;

select count(0) from TSWrestler;
select count(0) from TSWrestler_tmp;

drop table TSWrestler;

create table dbo.TSWrestler (
	ID int identity(1,1) not null primary key
	, TSSummaryID int not null
	, FloWrestlerID int null
	, TrackWrestlerID int null
	, Rating decimal(18,9) not null
	, Deviation decimal(18,9) not null
	, Volatility decimal(18,9) not null
	, InsertDate datetime not null default getdate()
	, ModifiedDate datetime not null default getdate()
);

set identity_insert TSWrestler on;

insert	TSWrestler (
		ID
		, TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Rating
		, Deviation
		, Volatility
		, InsertDate
		, ModifiedDate
		)
select	ID
		, TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Mean
		, StandardDeviation
		, Volatility
		, InsertDate
		, ModifiedDate
from	TSWrestler_tmp;

select count(0) from TSWrestler;
select count(0) from TSWrestler_tmp;
select top 100 * from TSWrestler order by newid();


-- ***************** Keys

alter table TSMatch add constraint fk_TSMatch_TSWrestler foreign key (TSWrestlerID) references TSWrestler (ID) on delete cascade on update cascade;
create index idx_TSMatch_TSWrestlerID on TSMatch (TSWrestlerID);

alter table TSWrestler add constraint fk_TSWrestler_TSSummary foreign key (TSSummaryID) references TSSummary (ID) on delete cascade on update cascade;
alter table TSWrestler add constraint fk_TSWrestler_FloWrestler foreign key (FloWrestlerID) references FloWrestler (ID) on delete cascade on update cascade;
alter table TSWrestler add constraint fk_TSWrestler_TrackWrestler foreign key (TrackWrestlerID) references TrackWrestler (ID) on delete cascade on update cascade;
create index idx_TSWrestler_TSSummaryID on TSWrestler (TSSummaryID);

drop table TSMatch_tmp;
drop table TSWrestler_tmp;
