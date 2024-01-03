
-- select	*
-- from	xx_TeamLineup
-- where	TeamName = 'river bluff'

-- select	*
-- from	FloWrestler
-- where	LastName like 'turner'
-- 		and FirstName = 'jack'

select	[Event] = case when TSMatch.IsFlo = 1 then FloOpponent.EventName else TrackOpponent.EventName end
		, TSMatch.IsWinner
		, Rank = cast(round(TSMatch.RatingInitial, 0) as int)
		, Diviation = cast(round(TSMatch.DeviationInitial, 0) as int)
		, Probability = round(dbo.G2Predict(TSMatch.RatingInitial, TSMatch.DeviationInitial, case when TSMatch.IsFlo = 1 then FloOpponent.Rank else TrackOpponent.Rank end, case when TSMatch.IsFlo = 1 then FloOpponent.SD else TrackOpponent.SD end) * 100, 2)
		, vs = case when TSMatch.IsFlo = 1 then FloOpponent.WrestlerName else TrackOpponent.WrestlerName end
		, vsTeam = case when TSMatch.IsFlo = 1 then FloOpponent.WrestlerTeam else TrackOpponent.WrestlerTeam end
		, vsRank = cast(round(case when TSMatch.IsFlo = 1 then FloOpponent.Rank else TrackOpponent.Rank end, 0) as int)
		, vsDeviaion = cast(round(case when TSMatch.IsFlo = 1 then FloOpponent.SD else TrackOpponent.SD end, 0) as int)
		, OpponentWinner = case when TSMatch.IsWinner = 1 then 0 else 1 end
from	TSWrestler
join	TSMatch
on		TSWrestler.ID = TSMatch.TSWrestlerID
outer apply (
		select	WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, WrestlerTeam = FloWrestler.TeamName
				, Rank = florank.Rating
				, SD = florank.Deviation
				, EventName = FloMeet.MeetName
		from	TSMatch flomatchrank
		join	TSWrestler florank
		on		flomatchrank.TSWrestlerID = florank.ID
				and TSWrestler.TSSummaryID = florank.TSSummaryID
		join	FloWrestler
		on		florank.FloWrestlerID = FloWrestler.ID
		join	FloMatch
		on		flomatchrank.MatchID = flomatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	TSMatch.MatchID = flomatchrank.MatchID
				and TSMatch.IsFlo = flomatchrank.IsFlo
				and TSMatch.ID <> flomatchrank.ID
		) FloOpponent
outer apply (
		select	WrestlerName = TrackWrestler.WrestlerName
				, WrestlerTeam = TrackWrestler.TeamName
				, Rank = trackrank.Rating
				, SD = trackrank.Deviation
				, EventName = TrackEvent.EventName
		from	TSMatch trackmatchrank
		join	TSWrestler trackrank
		on		trackmatchrank.TSWrestlerID = trackrank.ID
				and TSWrestler.TSSummaryID = trackrank.TSSummaryID
		join	TrackWrestler
		on		trackrank.TrackWrestlerID = TrackWrestler.ID
		join	TrackMatch
		on		trackmatchrank.MatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TSMatch.MatchID = trackmatchrank.MatchID
				and TSMatch.IsFlo = trackmatchrank.IsFlo
				and TSMatch.ID <> trackmatchrank.ID
		) TrackOpponent
where	TSWrestler.FloWrestlerID = 30649
		and TSWrestler.TSSummaryID = 51
order by
		TSMatch.Sort
