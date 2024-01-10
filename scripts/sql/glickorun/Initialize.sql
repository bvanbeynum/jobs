set nocount on;

declare @SummaryID int;
declare @Rating decimal(9,5);
declare @Deviation decimal(9,5);
declare @Volatility decimal(9,5);

set @SummaryID = ?;
set @Rating = ?;
set @Deviation = ?;
set @Volatility = ?;

delete
from	TSWrestler
where	TSSummaryID = @SummaryID;

insert	TSWrestler (
		TSSummaryID
		, FloWrestlerID
		, TrackWrestlerID
		, Rating
		, Deviation
		, Volatility
		)
select	TSSummaryID = @SummaryID
		, FloWrestlerID = max(FloWrestlerID)
		, TrackWrestlerID = max(TrackWrestlerID)
		, Rating = @Rating
		, Deviation = @Deviation
		, Volatility = @Volatility
from	(
		select	Wrestler = trim(FloWrestler.FirstName) + ' ' + trim(FloWrestler.LastName)
				, Team = trim(FloWrestler.TeamName)
				, FloWrestlerID = FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = null
				, EventCount = count(distinct FloMeet.ID)
		from	FloMeet
		join	FloMatch
		on		FloMeet.ID = FloMatch.FloMeetID
		join	FloWrestlerMatch
		on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		group by
				FloWrestlerMatch.FloWrestlerID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestler.TeamName

		union

		select	Wrestler = trim(TrackWrestler.WrestlerName)
				, Team = trim(TrackWrestler.TeamName)
				, FloWrestlerID = null
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, EventCount = count(distinct TrackEvent.ID)
		from	TrackEvent
		join	TrackMatch
		on		TrackEvent.ID = TrackMatch.TrackEventID
		join	TrackWrestlerMatch
		on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		group by
				TrackWrestlerMatch.TrackWrestlerID
				, TrackWrestler.WrestlerName
				, TrackWrestler.TeamName
		) AllWrestlers
group by
		Wrestler
		, Team
having	sum(EventCount) > 1;

declare @AllMatches table (
	EventID integer
	, MatchID integer
	, WinnerID integer
	, LoserID integer
	, MatchSort integer
	, IsFlo bit
);

insert	@AllMatches (
		EventID
		, MatchID
		, WinnerID
		, LoserID
		, MatchSort
		, IsFlo
		)
select	EventID
		, MatchID = case when FloMatchID is not null then FloMatchID else TrackMatchID end
		, WinnerID
		, LoserID
		, MatchSort = row_number() over (order by EventDate, Sort)
		, IsFlo = case when FloMatchID is not null then 1 else 0 end
from	(
		select	EventID = FloMatch.FloMeetID
				, FloMatchID = FloMatch.ID
				, TrackMatchID = cast(null as int)
				, WinnerID = max(case when FloWrestlerMatch.IsWinner = 1 then TSWrestler.ID else null end)
				, LoserID = max(case when FloWrestlerMatch.IsWinner = 0 then TSWrestler.ID else null end)
				, EventDate = cast(FloMeet.StartTime as date)
				, FloMatch.Sort
		from	FloMeet
		join	FloMatch
		on		FloMeet.ID = FloMatch.FloMeetID
		join	FloWrestlerMatch
		on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		join	TSWrestler
		on		FloWrestlerMatch.FloWrestlerID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		where	coalesce(FloMatch.Division, '') not like 'ms%'
				and coalesce(FloMatch.Division, '') not like 'jv%'
				and coalesce(FloMatch.Division, '') not like '%middle%'
				and coalesce(FloMatch.Division, '') not like '%junior%'
				and coalesce(FloMatch.WinType, '') not in ('bye', 'for', 'nc', 'm for', '')
		group by
				FloMatch.ID
				, cast(FloMeet.StartTime as date)
				, FloMatch.Sort
				, FloMatch.FloMeetID
		having	max(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end) = 1
				and max(case when FloWrestlerMatch.IsWinner = 0 then 1 else 0 end) = 1

		union

		select	EventID = TrackMatch.TrackEventID
				, FloMatchID = cast(null as int)
				, TrackMatchID = TrackMatch.ID
				, WinnerID = max(case when TrackWrestlerMatch.IsWinner = 1 then TSWrestler.ID else null end)
				, LoserID = max(case when TrackWrestlerMatch.IsWinner = 0 then TSWrestler.ID else null end)
				, EventDate = cast(TrackEvent.EventDate as date)
				, TrackMatch.Sort
		from	TrackEvent
		join	TrackMatch
		on		TrackEvent.ID = TrackMatch.TrackEventID
		join	TrackWrestlerMatch
		on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
		join	TSWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TSWrestler.TrackWrestlerID
				and TSWrestler.TSSummaryID = @SummaryID
		where	coalesce(TrackMatch.Division, '') not like 'ms%'
				and coalesce(TrackMatch.Division, '') not like 'jv%'
				and coalesce(TrackMatch.Division, '') not like '%middle%'
				and coalesce(TrackMatch.Division, '') not like '%junior%'
				and coalesce(TrackMatch.WinType, '') not in ('bye', 'for', 'nc', 'm for', '')
		group by
				TrackMatch.ID
				, cast(TrackEvent.EventDate as date)
				, TrackMatch.Sort
				, TrackMatch.TrackEventID
		having	max(case when TrackWrestlerMatch.IsWinner = 1 then 1 else 0 end) = 1
				and max(case when TrackWrestlerMatch.IsWinner = 0 then 1 else 0 end) = 1
		) AllMatches;

insert	TSMatch (
		TSWrestlerID
		, EventID
		, MatchID
		, IsWinner
		, Sort
		, IsFlo
		)
select	TSWrestlerID = TSWrestler.ID
		, AllMatches.EventID
		, AllMatches.MatchID
		, IsWinner = 1
		, AllMatches.MatchSort
		, AllMatches.IsFlo
from	@AllMatches AllMatches
join	TSWrestler
on		AllMatches.WinnerID = TSWrestler.ID
		and TSWrestler.TSSummaryID = @SummaryID;

insert	TSMatch (
		TSWrestlerID
		, EventID
		, MatchID
		, IsWinner
		, Sort
		, IsFlo
		)
select	TSWrestlerID = TSWrestler.ID
		, AllMatches.EventID
		, AllMatches.MatchID
		, IsWinner = 0
		, AllMatches.MatchSort
		, AllMatches.IsFlo
from	@AllMatches AllMatches
join	TSWrestler
on		AllMatches.LoserID = TSWrestler.ID
		and TSWrestler.TSSummaryID = @SummaryID;

select	Events = count(distinct cast(TSMatch.MatchID as varchar(255)) + '|' + cast(TSMatch.IsFlo as varchar(255)))
from	TSWrestler
join	TSMatch
on		TSWrestler.ID = TSMatch.TSWrestlerID
where	TSWrestler.TSSummaryID = @SummaryID
		and TSMatch.WinProbability is null;

set nocount off;