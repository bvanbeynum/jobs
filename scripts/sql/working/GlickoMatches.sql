
-- select	*
-- from	xx_TeamLineup
-- where	TeamName = 'river bluff'

select	[Event] = case when TSMatch.FloMatchID is not null then FloOpponent.EventName else TrackOpponent.EventName end
		, TSMatch.IsWinner
		, Rank = TSMatch.MeanInitial
		, Diviation = TSMatch.StandardDeviationInitial
		, vs = case when TSMatch.FloMatchID is not null then FloOpponent.WrestlerName else TrackOpponent.WrestlerName end
		, vsTeam = case when TSMatch.FloMatchID is not null then FloOpponent.WrestlerTeam else TrackOpponent.WrestlerTeam end
		, vsRank = case when TSMatch.FloMatchID is not null then FloOpponent.Rank else TrackOpponent.Rank end
		, vsDeviaion = case when TSMatch.FloMatchID is not null then FloOpponent.SD else TrackOpponent.SD end
		, OpponentWinner = case when TSMatch.IsWinner = 1 then 0 else 1 end
from	TSWrestler
join	TSMatch
on		TSWrestler.ID = TSMatch.TSWrestlerID
outer apply (
		select	WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, WrestlerTeam = FloWrestler.TeamName
				, Rank = florank.Mean
				, SD = florank.StandardDeviation
				, EventName = FloMeet.MeetName
		from	TSMatch flomatchrank
		join	TSWrestler florank
		on		flomatchrank.TSWrestlerID = florank.ID
				and TSWrestler.TSSummaryID = florank.TSSummaryID
		join	FloWrestler
		on		florank.FloWrestlerID = FloWrestler.ID
		join	FloMatch
		on		flomatchrank.FloMatchID = flomatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	TSMatch.FloMatchID = flomatchrank.FloMatchID
				and TSMatch.ID <> flomatchrank.ID
		) FloOpponent
outer apply (
		select	WrestlerName = TrackWrestler.WrestlerName
				, WrestlerTeam = TrackWrestler.TeamName
				, Rank = trackrank.Mean
				, SD = trackrank.StandardDeviation
				, EventName = TrackEvent.EventName
		from	TSMatch trackmatchrank
		join	TSWrestler trackrank
		on		trackmatchrank.TSWrestlerID = trackrank.ID
				and TSWrestler.TSSummaryID = trackrank.TSSummaryID
		join	TrackWrestler
		on		trackrank.TrackWrestlerID = TrackWrestler.ID
		join	TrackMatch
		on		trackmatchrank.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TSMatch.TrackMatchID = trackmatchrank.TrackMatchID
				and TSMatch.ID <> trackmatchrank.ID
		) TrackOpponent
where	TSWrestler.FloWrestlerID = 17747
		and TSWrestler.TSSummaryID = 22
order by
		TSMatch.Sort
