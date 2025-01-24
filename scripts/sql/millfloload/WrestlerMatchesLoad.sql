set nocount on;

declare @WrestlerMatch table (
	WrestlerID int
	, FirstName varchar(255)
	, LastName varchar(255)
	, Team varchar(255)
	, gRating decimal(18,9)
	, gDeviation decimal(18,9)
	, IsLineageModified int
	, EventID int
	, EventDate date
	, EventName varchar(255)
	, LocationState varchar(255)
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

insert	@WrestlerMatch (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		, IsLineageModified
		, EventID
		, EventDate
		, EventName
		, LocationState
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
		, FloWrestlerMatch.Team
		, wrestlers.gRating
		, wrestlers.gDeviation
		, wrestlers.IsLineageModified
		, EventID = FloMeet.ID
		, EventDate = cast(FloMeet.StartTime as date)
		, EventName = FloMeet.MeetName
		, FloMeet.LocationState
		, FloMatch.Division
		, FloMatch.WeightClass
		, FloMatch.RoundName
		, FloWrestlerMatch.IsWinner
		, FloMatch.WinType
		, FloMatch.Sort
		, vs = opponent.FirstName + ' ' + opponent.LastName
		, vsTeam = vsmatch.Team
		, vsID = opponent.ID
from	#WrestlerLoadBatch wrestlers
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
		and FloMeet.StartTime > getdate() - (365 * 2);

insert	@WrestlerMatch (
		WrestlerID
		, FirstName
		, LastName
		, Team
		, gRating
		, gDeviation
		, IsLineageModified
		, EventID
		, EventDate
		, EventName
		, LocationState
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
		, TrackWrestlerMatch.Team
		, wrestlers.gRating
		, wrestlers.gDeviation
		, wrestlers.IsLineageModified
		, EventID = TrackEvent.ID
		, EventDate = cast(TrackEvent.EventDate as date)
		, TrackEvent.EventName
		, TrackEvent.EventState
		, TrackMatch.Division
		, TrackMatch.WeightClass
		, TrackMatch.RoundName
		, TrackWrestlerMatch.IsWinner
		, TrackMatch.WinType
		, TrackMatch.Sort
		, vs = opponent.WrestlerName
		, vsTeam = vsmatch.Team
		, vsID = OpponentFlo.WrestlerID
from	#WrestlerLoadBatch wrestlers
join	TrackWrestler
on		wrestlers.FirstName + ' ' + wrestlers.LastName = TrackWrestler.WrestlerName
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		and wrestlers.Teams like '%|' + TrackWrestlerMatch.Team + '|%'
join	TrackMatch
on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
join	TrackEvent
on		TrackMatch.TrackEventID = TrackEvent.ID
join	TrackWrestlerMatch vsmatch
on		TrackMatch.ID = vsmatch.TrackMatchID
		and vsmatch.TrackWrestlerID <> TrackWrestler.ID
join	TrackWrestler opponent
on		vsmatch.TrackWrestlerID = opponent.ID
outer apply (
		select	top 1 WrestlerID = FloWrestler.ID
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		where	opponent.WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				and FloWrestlerMatch.Team = vsmatch.Team
		) OpponentFlo
where	TrackEvent.IsComplete = 1
		and TrackEvent.EventDate > getdate() - (365 * 2);

select	*
from	@WrestlerMatch
order by
		WrestlerID
		, EventDate
		, EventID
		, Sort;

set nocount off;