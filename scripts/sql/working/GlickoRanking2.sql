
if object_id('tempdb..#LastFlo') is not null
	drop table #LastFlo

if object_id('tempdb..#LastTrack') is not null
	drop table #LastTrack

declare @StartDate date

set @StartDate = cast('11/1/2024' as date)

select	WeightClass
		, WrestlerID
		, WrestlerName
		, Teams = string_agg(Team, ', ') within group (order by LastEvent desc)
		, LastEvent = max(LastEvent)
into	#LastFlo
from	(
		select	WrestlerID = FloWrestler.ID
				, FloMatch.WeightClass
				, FloWrestlerMatch.Team
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, LastEvent = max(cast(FloMeet.StartTime as date))
		from	FloMeet
		join	FloMatch
		on		FloMeet.ID = FloMatch.FloMeetID
		join	FloWrestlerMatch
		on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		where	FloMeet.StartTime > @StartDate
				and isnumeric(FloMatch.WeightClass) = 1
				and FloMeet.LocationState = 'sc'
		group by
				FloWrestler.ID
				, FloMatch.WeightClass
				, FloWrestlerMatch.Team
				, FloWrestler.FirstName
				, FloWrestler.LastName
		) Wrestlers
group by
		WeightClass
		, WrestlerID
		, WrestlerName

select	WeightClass
		, WrestlerID
		, WrestlerName
		, Teams = string_agg(Team, ', ') within group (order by LastEvent desc)
		, LastEvent = max(LastEvent)
into	#LastTrack
from	(
		select	WrestlerID = FloWrestlerMatch.FloWrestlerID
				, TrackMatch.WeightClass
				, TrackWrestlerMatch.Team
				, TrackWrestler.WrestlerName
				, LastEvent = max(cast(TrackEvent.EventDate as date))
		from	TrackEvent
		join	TrackMatch
		on		TrackEvent.ID = TrackMatch.TrackEventID
		join	TrackWrestlerMatch
		on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		join	FloWrestlerMatch
		on		TrackWrestler.WrestlerName = FloWrestlerMatch.FirstName + ' ' + FloWrestlerMatch.LastName
				and TrackWrestlerMatch.Team = FloWrestlerMatch.Team
		where	TrackEvent.EventDate > @StartDate
				and isnumeric(TrackMatch.WeightClass) = 1
				and TrackEvent.EventState = 'sc'
		group by
				FloWrestlerMatch.FloWrestlerID
				, TrackMatch.WeightClass
				, TrackWrestlerMatch.Team
				, TrackWrestler.WrestlerName
		) Wrestlers
group by
		WeightClass
		, WrestlerID
		, WrestlerName

select	AllWrestlers.WeightClass
		, Rank = rank() over (partition by AllWrestlers.WeightClass order by RatingCalc.conservativerating desc)
		, Wrestler = AllWrestlers.WrestlerName
		, Teams = string_agg(AllWrestlers.Teams, ',')
		, Rating = round(FloWrestler.GRating, 0)
		, Confidence = round(FloWrestler.GDeviation, 0)
from	(
		select	WrestlerID
				, WrestlerName
				, WeightClass
				, Teams
		from	#LastFlo
		union
		select	WrestlerID
				, WrestlerName
				, WeightClass
				, Teams
		from	#LastTrack
		) AllWrestlers
join	FloWrestler
on		AllWrestlers.WrestlerID = FloWrestler.ID
cross apply (
		select	FloWrestler.GRating - (3 * FloWrestler.GDeviation) ConservativeRating
		) RatingCalc
-- where	AllWrestlers.WeightClass = '113'
group by
		AllWrestlers.WeightClass
		, RatingCalc.ConservativeRating
		, AllWrestlers.WrestlerName
		, FloWrestler.GRating
		, FloWrestler.GDeviation
order by
		cast(AllWrestlers.WeightClass as int)
		, rank
