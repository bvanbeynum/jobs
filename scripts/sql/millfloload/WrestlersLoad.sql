set nocount on;

declare @Wrestler table (
	WrestlerID int
	, FirstName varchar(255)
	, LastName varchar(255)
	, Team varchar(255)
	, gRating decimal(18,9)
	, gDeviation decimal(18,9)
);

declare @WrestlerMatch table (
	WrestlerID int
	, FirstName varchar(255)
	, LastName varchar(255)
	, Team varchar(255)
	, gRating decimal(18,9)
	, gDeviation decimal(18,9)
	, EventID int
	, EventDate date
	, EventName varchar(255)
	, Division varchar(255)
	, WeightClass varchar(255)
	, RoundName varchar(255)
	, IsWinner bit
	, WinType varchar(255)
	, Sort int
	, vs varchar(500)
	, vsTeam varchar(255)
	, vsID int
);

-- Get Flo wrestlers that've changed in the past 2 days
insert	@Wrestler (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		)
select	WrestlerID = FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, Team = FloWrestler.TeamName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	FloMeet.IsExcluded = 0
		and FloMeet.LocationState = 'sc'
group by
		FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.TeamName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
having	max(case when FloMatch.ModifiedDate > getdate() - 2 then 1 else 0 end) = 1;

-- Get Track wrestlers that've changed in the past 2 days
insert	@Wrestler (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		)
select	WrestlerID = FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, Team = FloWrestler.TeamName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
from	FloWrestler
join	TrackWrestler
on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
join	TrackMatch
on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
join	TrackEvent
on		TrackMatch.TrackEventID = TrackEvent.ID
outer apply (
		select	top 1 Wrestler.WrestlerID
		from	@Wrestler Wrestler
		where	FloWrestler.ID = Wrestler.WrestlerID
		) ExistingWrestler
where	TrackEvent.IsComplete = 1
		and TrackEvent.EventState = 'sc'
		and ExistingWrestler.WrestlerID = 0
group by
		FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.TeamName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
having	max(case when TrackMatch.ModifiedDate > getdate() - 2 then 1 else 0 end) = 1;

insert	@WrestlerMatch (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		, EventID
		, EventDate
		, EventName
		, Division
		, WeightClass
		, RoundName
		, IsWinner
		, WinType
		, Sort
		, vs
		, vsTeam
		, vsID
		)
select	wrestlers.WrestlerID
		, wrestlers.FirstName
		, wrestlers.LastName
		, wrestlers.Team
		, wrestlers.gRating
		, wrestlers.gDeviation
		, EventID = FloMeet.ID
		, EventDate = cast(FloMeet.StartTime as date)
		, EventName = FloMeet.MeetName
		, FloMatch.Division
		, FloMatch.WeightClass
		, FloMatch.RoundName
		, FloWrestlerMatch.IsWinner
		, FloMatch.WinType
		, FloMatch.Sort
		, vs = opponent.FirstName + ' ' + opponent.LastName
		, vsTeam = opponent.TeamName
		, vsID = opponent.ID
from	@Wrestler wrestlers
join	FloWrestlerMatch
on		wrestlers.WrestlerID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
join	FloWrestlerMatch vsmatch
on		FloMatch.ID = vsmatch.FloMatchID
		and vsmatch.FloWrestlerID <> wrestlers.WrestlerID
join	FloWrestler opponent
on		vsmatch.FloWrestlerID = opponent.ID
where	FloMeet.IsExcluded = 0
		and FloMeet.StartTime > getdate() - (365 * 2)
		and FloMatch.WinType is not null;

insert	@WrestlerMatch (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		, EventID
		, EventDate
		, EventName
		, Division
		, WeightClass
		, RoundName
		, IsWinner
		, WinType
		, Sort
		, vs
		, vsTeam
		, vsID
		)
select	wrestlers.WrestlerID
		, wrestlers.FirstName
		, wrestlers.LastName
		, wrestlers.Team
		, wrestlers.gRating
		, wrestlers.gDeviation
		, EventID = TrackEvent.ID
		, EventDate = cast(TrackEvent.EventDate as date)
		, EventName = TrackEvent.EventName
		, TrackMatch.Division
		, TrackMatch.WeightClass
		, TrackMatch.RoundName
		, TrackWrestlerMatch.IsWinner
		, TrackMatch.WinType
		, TrackMatch.Sort
		, vs = opponent.FirstName + ' ' + opponent.LastName
		, vsTeam = opponent.TeamName
		, vsID = opponent.ID
from	@Wrestler wrestlers
join	TrackWrestler
on		wrestlers.FirstName + ' ' + wrestlers.LastName = TrackWrestler.WrestlerName
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
join	TrackMatch
on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
join	TrackEvent
on		TrackMatch.TrackEventID = TrackEvent.ID
join	TrackWrestlerMatch vsmatch
on		TrackMatch.ID = vsmatch.TrackMatchID
		and vsmatch.TrackWrestlerID <> wrestlers.WrestlerID
join	FloWrestler opponent
on		vsmatch.TrackWrestlerID = opponent.ID
where	TrackEvent.IsComplete = 1
		and TrackEvent.EventDate > getdate() - (365 * 2)
		and TrackMatch.WinType is not null;

select	*
from	@WrestlerMatch
order by
		WrestlerID
		, EventDate
		, EventID
		, Sort;

set nocount off;