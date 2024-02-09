set nocount on;

if object_id('tempdb..#NewMatches') is not null
	drop table #NewMatches;

declare @SummaryID int;
declare @Rating decimal(9,5);
declare @Deviation decimal(9,5);
declare @Volatility decimal(9,5);

set @SummaryID = 51;
set @Rating = ?;
set @Deviation = ?;
set @Volatility = ?;

create table #NewMatches (
	EventID int
	, IsFlo bit
	, EventDate date
	, MatchID int
	, TSWrestlerID int
	, FloWrestlerID int
	, TrackWrestlerID int
	, IsWinner bit
	, Sort int
);

insert	#NewMatches (
		EventID
		, IsFlo
		, EventDate
		, MatchID
		, TSWrestlerID
		, FloWrestlerID
		, TrackWrestlerID
		, IsWinner
		, Sort
		)
select	EventID
		, IsFlo = case when FloMatchID is not null then 1 else 0 end
		, EventDate
		, MatchID = case when FloMatchID is not null then FloMatchID else TrackMatchID end
		, TSWrestlerID
		, FloWrestlerID
		, TrackWrestlerID
		, IsWinner
		, Sort = row_number() over (order by EventDate, Sort)
from	(
		select	EventID = FloMatch.FloMeetID
				, EventDate = cast(FloMeet.StartTime as date)
				, FloMatchID = FloMatch.ID
				, TrackMatchID = cast(null as int)
				, TSWrestlerID = TSWrestler.ID
				, FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = cast(null as int)
				, FloWrestlerMatch.IsWinner
				, FloMatch.Sort
		from	FloMeet
		join	FloMatch
		on		FloMeet.ID = FloMatch.FloMeetID
		join	FloWrestlerMatch
		on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		left join
				TSWrestler
		on		FloWrestlerMatch.FloWrestlerID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		left join
				TSMatch
		on		TSWrestler.ID = TSMatch.TSWrestlerID
				and FloWrestlerMatch.FloMatchID = TSMatch.MatchID
				and TSMatch.IsFlo = 1
		where	coalesce(FloMatch.Division, '') not like 'ms%'
				and coalesce(FloMatch.Division, '') not like 'jv%'
				and coalesce(FloMatch.Division, '') not like '%middle%'
				and coalesce(FloMatch.Division, '') not like '%junior%'
				and coalesce(FloMatch.WinType, '') not in ('bye', 'for', 'nc', 'm for')
				and TSMatch.ID is null

		union all

		select	EventID = TrackEvent.ID
				, EventDate = cast(TrackEvent.EventDate as date)
				, FloMatchID = cast(null as int)
				, TrackMatchID = TrackMatch.ID
				, TSWrestlerID = TSWrestler.ID
				, FloWrestlerID = cast(null as int)
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, TrackWrestlerMatch.IsWinner
				, TrackMatch.Sort
		from	TrackEvent
		join	TrackMatch
		on		TrackEvent.ID = TrackMatch.TrackEventID
		join	TrackWrestlerMatch
		on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
		left join
				TSWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TSWrestler.TrackWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		left join
				TSMatch
		on		TSWrestler.ID = TSMatch.TSWrestlerID
				and TrackWrestlerMatch.TrackMatchID = TSMatch.MatchID
				and TSMatch.IsFlo = 0
		where	coalesce(TrackMatch.Division, '') not like 'ms%'
				and coalesce(TrackMatch.Division, '') not like 'jv%'
				and coalesce(TrackMatch.Division, '') not like '%middle%'
				and coalesce(TrackMatch.Division, '') not like '%junior%'
				and coalesce(TrackMatch.WinType, '') not in ('bye', 'for', 'nc', 'm for')
				and TSMatch.ID is null
		) AllMatches;

-- Populate the flo wrestler ID when they have a track wrestler ID
update	TSWrestler
set		FloWrestlerID = UpdateData.FloWrestlerID
from	TSWrestler
join	(
		select	distinct TSWrestlerID = TSWrestler.ID
				, NewMatches.FloWrestlerID
		from	#NewMatches NewMatches
		join	FloWrestler
		on		NewMatches.FloWrestlerID = FloWrestler.ID
		join	TrackWrestler
		on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
				and FloWrestler.TeamName = TrackWrestler.TeamName
		join	TSWrestler
		on		TrackWrestler.ID = TSWrestler.TrackWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		where	NewMatches.TSWrestlerID is null
		) UpdateData
on		TSWrestler.ID = UpdateData.TSWrestlerID;

-- Populate the track wrestler ID when they have a flo wrestler ID
update	TSWrestler
set		TrackWrestlerID = UpdateData.TrackWrestlerID
from	TSWrestler
join	(
		select	distinct TSWrestlerID = TSWrestler.ID
				, NewMatches.TrackWrestlerID
		from	#NewMatches NewMatches
		join	TrackWrestler
		on		NewMatches.TrackWrestlerID = TrackWrestler.ID
		join	FloWrestler
		on		TrackWrestler.WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				and TrackWrestler.TeamName = FloWrestler.TeamName
		join	TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		where	NewMatches.TSWrestlerID is null
		) UpdateData
on		TSWrestler.ID = UpdateData.TSWrestlerID;

-- Add new flo wrestlers (get track wrestler ID where found)
insert	TSWrestler (
		TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Rating
		, Deviation
		, Volatility
)
select	TSSummaryID = @SummaryID
		, NewMatches.FloWrestlerID
		, TrackWrestlerID = TrackWrestler.ID
		, 1500.0
		, 450.0
		, 0.06
from	#NewMatches NewMatches
join	FloWrestler
on		NewMatches.FloWrestlerID = FloWrestler.ID
left join
		TrackWrestler
on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
		and FloWrestler.TeamName = TrackWrestler.TeamName
left join
		TSWrestler
on		NewMatches.FloWrestlerID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = @SummaryID
where	TSWrestler.ID is null
group by
		NewMatches.FloWrestlerID
		, TrackWrestler.ID;

-- Add new track wrestlers (get flo wrestler ID where found)
insert	TSWrestler (
		TSSummaryID
		, TrackWrestlerID
		, FloWrestlerID
		, Rating
		, Deviation
		, Volatility
)
select	TSSummaryID = @SummaryID
		, NewMatches.TrackWrestlerID
		, FloWrestlerID = FloWrestler.ID
		, 1500.0
		, 450.0
		, 0.06
from	#NewMatches NewMatches
join	TrackWrestler
on		NewMatches.TrackWrestlerID = TrackWrestler.ID
left join
		FloWrestler
on		TrackWrestler.WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		and TrackWrestler.TeamName = FloWrestler.TeamName
left join
		TSWrestler
on		NewMatches.TrackWrestlerID = TSWrestler.TrackWrestlerID
		and TSWrestler.TSSummaryID = @SummaryID
where	TSWrestler.ID is null
group by
		NewMatches.TrackWrestlerID
		, FloWrestler.ID;

insert	TSMatch (
		TSWrestlerID
		, IsFlo
		, EventID
		, EventDate
		, MatchID
		, IsWinner
		, Sort
		)
select	TSWrestlerID = coalesce(TSFlow.id, TSTrack.id)
		, IsFlo = NewMatches.IsFlo
		, EventID = NewMatches.EventID
		, EventDate = NewMatches.EventDate
		, MatchID = NewMatches.MatchID
		, IsWinner = NewMatches.IsWinner
		, Sort = NewMatches.Sort
from	#NewMatches NewMatches
left join
		TSWrestler TSFlow
on		NewMatches.FloWrestlerID = TSFlow.FloWrestlerID
		and TSFlow.TSSummaryID = @SummaryID
left join
		TSWrestler TSTrack
on		NewMatches.TrackWrestlerID = TSTrack.TrackWrestlerID
		and TSTrack.TSSummaryID = @SummaryID
where	TSFlow.id is not null or TSTrack.ID is not null;

select	TotalBatches = count(distinct cast(datepart(yyyy, EventDate) as varchar(max)) + '.' + cast(datepart(wk, EventDate) as varchar(max)))
from	TSMatch
join	TSWrestler
on		TSMatch.TSWrestlerID = TSWrestler.ID
cross apply (
		select	ID = cast(FilterMatch.MatchID as varchar(max)) + '.' + cast(FilterMatch.IsFlo as varchar(max))
		from	TSMatch FilterMatch
		join	TSWrestler FilterWrestler
		on		FilterMatch.TSWrestlerID = FilterWrestler.ID
		where	FilterWrestler.TSSummaryID = TSWrestler.TSSummaryID
				and TSMatch.IsFlo = FilterMatch.IsFlo
				and TSMatch.MatchID = FilterMatch.MatchID
		group by
				FilterMatch.MatchID
				, FilterMatch.IsFlo
		having	count(distinct FilterMatch.ID) > 1
		) FilterMatches
where	TSWrestler.TSSummaryID = @SummaryID
		and TSMatch.RatingUpdate is null;

set nocount off;
