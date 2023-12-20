return;

select * from TSSummary

select	FloMatch.PoolName
		, FloMatch.RoundName
		, FloMatch.RoundSpot
		, FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, TSWrestler.Mean
		, TSWrestler.StandardDeviation
		, FloWrestler.ID
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
join	FloWrestler
on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
left join
		TSWrestler
on		FloWrestler.ID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = 18
where	FloMeet.ID = 11559
		and FloMatch.WeightClass = '106'
order by
		FloMatch.PoolName
		, FloMatch.RoundName
		, FloMatch.RoundSpot

select	TrackEvent.eventdate
		, TrackEvent.eventname
		, TrackMatch.WeightClass
from	TrackEvent
join	TrackMatch
on		TrackEvent.ID = TrackMatch.TrackEventID
join	TrackWrestlerMatch
on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
join	TrackWrestler
on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
where	TrackWrestler.id = 20836
group by
		TrackEvent.eventdate
		, TrackEvent.eventname
		, TrackMatch.WeightClass

select	TrackMatch.WeightClass
		, Wrestler = case when winner.TeamName = 'river bluff' then winner.WrestlerName else loser.WrestlerName end
		, TrackMatch.RoundName
		, Result = case when winner.TeamName = 'river bluff' then 'beat' else 'lost to' end
		, VS = case when winner.TeamName = 'river bluff' then loser.WrestlerName else winner.WrestlerName end
		, VSTeam = case when winner.TeamName = 'river bluff' then loser.TeamName else winner.TeamName end
		, TrackMatch.WinType
from	TrackEvent
join	TrackMatch
on		TrackEvent.ID = TrackMatch.TrackEventID
left join
		TrackWrestlerMatch winnermatch
on		TrackMatch.ID = winnermatch.TrackMatchID
		and winnermatch.IsWinner = 1
left join
		TrackWrestler winner
on		winnermatch.TrackWrestlerID = winner.ID
left join
		TrackWrestlerMatch losermatch
on		TrackMatch.ID = losermatch.TrackMatchID
		and losermatch.IsWinner = 0
left join
		TrackWrestler loser
on		losermatch.TrackWrestlerID = loser.ID
where	TrackEvent.ID = 2165
		and (winner.TeamName = 'river bluff' or loser.TeamName = 'river bluff')
order by
		case when isnumeric(TrackMatch.WeightClass) = 1 then cast(TrackMatch.WeightClass as int) else 99 end
		, TrackMatch.Sort

select	*
from	TrackWrestler
where	WrestlerName like '%dillon'

select	*
from	TSWrestler
where	TrackWrestlerID in (2004)

select	*
from	dbo.Glicko2Predict(1500, 1400, 50, 40, 0.06)
