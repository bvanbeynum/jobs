
with LastEventCTE as (
select	WrestlerName
		, EventDate
		, EventName
		, WeightClass
from	(
		select	WrestlerName
				, EventDate
				, EventName
				, WeightClass
				, RowNumber = row_number() over (partition by WrestlerName order by EventDate desc)
		from	(
				select	WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
						, EventDate = cast(FloMeet.StartTime as date)
						, EventName = FloMeet.MeetName
						, FloMatch.WeightClass
				from	FloWrestler
				join	FloWrestlerMatch
				on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
				join	FloMatch
				on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				join	FloMeet
				on		FloMatch.FloMeetID = FloMeet.ID
				where	FloMeet.StartTime > '3/1/2024'
				group by
						FloWrestler.ID
						, FloWrestler.FirstName
						, FloWrestler.LastName
						, FloMeet.StartTime
						, FloMeet.MeetName
						, FloMatch.WeightClass
				union all
				select	TrackWrestler.WrestlerName
						, TrackEvent.EventDate
						, TrackEvent.EventName
						, TrackMatch.WeightClass
				from	TrackWrestler
				join	TrackWrestlerMatch
				on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
				join	TrackMatch
				on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
				join	TrackEvent
				on		TrackMatch.TrackEventID = TrackEvent.ID
				where	TrackEvent.EventDate > '3/1/2024'
				group by
						TrackWrestler.ID
						, TrackWrestler.WrestlerName
						, TrackEvent.EventDate
						, TrackEvent.EventName
						, TrackMatch.WeightClass
				) WrestlerEvent
		) LastEvent
where	RowNumber = 1
)
select	WrestlerRank.Ranking
		, WrestlerRank.Confrence
		, Wrestler = WrestlerRank.FirstName + ' ' + WrestlerRank.LastName
		, WrestlerRank.TeamName
		, WrestlerRank.Grade
		, LastEventCTE.WeightClass
		, LastEventCTE.EventDate
		, LastEventCTE.EventName
from	WrestlerRank
left join
		LastEventCTE
on		WrestlerRank.FirstName + ' ' + WrestlerRank.LastName = LastEventCTE.WrestlerName
where	WrestlerRank.WeightClass = '138'
		and WrestlerRank.SourceDate = '2/21/2024'
order by
		WrestlerRank.Ranking
		, WrestlerRank.Confrence desc

