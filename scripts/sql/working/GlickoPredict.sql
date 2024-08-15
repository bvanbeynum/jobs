
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

declare @OpponentTeam varchar(255)
set @OpponentTeam = 'Summerville'

if object_id('tempdb..#wrestlers') is not null
	drop table #Wrestlers

select	WrestlerID = row_number() over (order by coalesce(max(wrestlers.FloWrestlerID), max(wrestlers.TrackWrestlerID)))
		, FloWrestlerID = max(wrestlers.FloWrestlerID)
		, TrackWrestlerID = max(wrestlers.TrackWrestlerID)
		, Wrestlers.WrestlerName
into	#Wrestlers
from	(
		select	FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = cast(null as int)
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		from	FloWrestlerMatch
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		where	FloWrestlerMatch.team = @OpponentTeam
		union
		select	FloWrestlerID = cast(null as int)
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, WrestlerName = TrackWrestler.WrestlerName
		from	TrackWrestlerMatch
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		where	TrackWrestlerMatch.team = @OpponentTeam
		) Wrestlers
group by
		Wrestlers.WrestlerName;

select	Team.WeightClass
		, Opponent.Wrestler
		, OpponentPrediciton = round(Opponent.Prediction * 100, 2)
		, FMPrediciton = round((1 - Opponent.Prediction) * 100, 2)
		, team.Wrestler
		, FMRank = team.Ranking
		, FMDeviation = team.Deviation
		, OpponentRank = Opponent.Ranking
		, OpponentDeviation = Opponent.Deviation
from	(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Ranking = FloWrestler.GRating
				, Deviation = FloWrestler.GDeviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
		where	TeamLineup.TeamName = 'fort mill'
		) Team
left join
		(
		select	FloWrestler.ID
				, TeamLineup.WeightClass
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Prediction = TeamLineup.VsFMPredict
				, Ranking = FloWrestler.GRating
				, Deviation = FloWrestler.GDeviation
		from	xx_TeamLineup TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		left join
				TSWrestler
		on		FloWrestler.ID = TSWrestler.FloWrestlerID
				and TSWrestler.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
		where	TeamLineup.TeamName = @OpponentTeam
		) Opponent
on		team.WeightClass = Opponent.WeightClass
order by
		Team.WeightClass

select	WeightClass
		, Wrestler
		, EventDate
		, [Event]
		, Division
		, EventWeight
		, RoundName
		, Rating
		, Result
		, Vs
		, Team
		, WinType
from	(
		select	
				-- WeightClass = TeamLineup.WeightClass -- last_value(TrackMatch.WeightClass) over (partition by TeamLineup.WrestlerID order by TrackEvent.EventDate desc, TrackMatch.Sort desc)
				WeightClass = first_value(FloMatch.WeightClass) over (partition by TeamLineup.WrestlerID order by FloMeet.StartTime desc, FloMatch.Sort desc)
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, EventDate = cast(FloMeet.StartTime as date)
				, [Event] = FloMeet.MeetName
				, FloMatch.Division
				, EventWeight = FloMatch.WeightClass
				, FloMatch.RoundName
				, Rating = cast(cast(WrestlerRating.Rating as int) as varchar(max))
				, Result = case 
					when FloWrestlerMatch.IsWinner = 1 then 'Beat' 
					when FloWrestlerMatch.IsWinner = 0 then 'Lost To' 
					else '' end
				, Vs = Opponent.FirstName + ' ' + Opponent.LastName + ' (' + cast(cast(coalesce(OpponentRating.Rating, 0) as int) as varchar(max)) + ')'
				, Team = Opponent.TeamName
				, FloMatch.WinType
				, FloMatch.Sort
				, MatchID = FloMatch.ID
		-- from	xx_TeamLineup TeamLineup
		from	#Wrestlers TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
				from	TSWrestler
				join	TSMatch
				on		TSWrestler.ID = TSMatch.TSWrestlerID
				where	TSWrestler.TSSummaryID = (select max(id) from TSSummary)
						and FloWrestler.ID = TSWrestler.FloWrestlerID
						and FloWrestlerMatch.FloMatchID = TSMatch.MatchID
						and TSMatch.IsFlo = 1
				) WrestlerRating
		join	FloWrestlerMatch OpponentMatch
		on		FloWrestlerMatch.FloMatchID = OpponentMatch.FloMatchID
				and FloWrestlerMatch.FloWrestlerID <> OpponentMatch.FloWrestlerID
		join	FloWrestler Opponent
		on		OpponentMatch.FloWrestlerID = Opponent.ID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
				from	TSWrestler
				join	TSMatch
				on		TSWrestler.ID = TSMatch.TSWrestlerID
				where	TSWrestler.TSSummaryID = (select max(id) from TSSummary)
						and Opponent.ID = TSWrestler.FloWrestlerID
						and FloWrestlerMatch.FloMatchID = TSMatch.MatchID
						and TSMatch.IsFlo = 1
				) OpponentRating
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				-- and FloMatch.WinType is not null
				and coalesce(FloMatch.WinType, '') <> 'bye'
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	1 = 1
				-- and TeamLineup.TeamName = @OpponentTeam
				and FloWrestlerMatch.Team = @OpponentTeam
		union all
		select	
				-- WeightClass = TeamLineup.WeightClass
				WeightClass = first_value(TrackMatch.WeightClass) over (partition by TeamLineup.WrestlerID order by TrackEvent.EventDate desc, TrackMatch.Sort desc)
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, EventDate = cast(TrackEvent.EventDate as date)
				, [Event] = TrackEvent.EventName
				, TrackMatch.Division
				, EventWeight = TrackMatch.WeightClass
				, TrackMatch.RoundName
				, Rating = cast(cast(WrestlerRating.Rating as int) as varchar(max))
				, Result = case 
					when TrackWrestlerMatch.IsWinner = 1 then 'Beat' 
					when TrackWrestlerMatch.IsWinner = 0 then 'Lost To' 
					else '' end
				, Vs = Opponent.WrestlerName + ' (' + cast(cast(coalesce(OpponentRating.Rating, 0) as int) as varchar(max)) + ')'
				, Team = Opponent.TeamName
				, TrackMatch.WinType
				, TrackMatch.Sort
				, MatchID = TrackMatch.ID
		-- from	xx_TeamLineup TeamLineup
		from	#Wrestlers TeamLineup
		join	FloWrestler
		on		TeamLineup.FloWrestlerID = FloWrestler.ID
		join	TrackWrestler
		on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
				from	TSWrestler
				join	TSMatch
				on		TSWrestler.ID = TSMatch.TSWrestlerID
				where	TSWrestler.TSSummaryID = (select max(id) from TSSummary)
						and TrackWrestler.ID = TSWrestler.TrackWrestlerID
						and TrackWrestlerMatch.TrackMatchID = TSMatch.MatchID
						and TSMatch.IsFlo = 0
				) WrestlerRating
		join	TrackWrestlerMatch OpponentMatch
		on		TrackWrestlerMatch.TrackMatchID = OpponentMatch.TrackMatchID
				and TrackWrestlerMatch.TrackWrestlerID <> OpponentMatch.TrackWrestlerID
		join	TrackWrestler Opponent
		on		OpponentMatch.TrackWrestlerID = Opponent.ID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
				from	TSWrestler
				join	TSMatch
				on		TSWrestler.ID = TSMatch.TSWrestlerID
				where	TSWrestler.TSSummaryID = (select max(id) from TSSummary)
						and Opponent.ID = TSWrestler.TrackWrestlerID
						and TrackWrestlerMatch.TrackMatchID = TSMatch.MatchID
						and TSMatch.IsFlo = 0
				) OpponentRating
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	1 = 1
				-- and TeamLineup.TeamName = @OpponentTeam
				and TrackWrestlerMatch.Team = @OpponentTeam
				-- and TrackMatch.WinType is not null
				and coalesce(TrackMatch.WinType, '') <> 'bye'
		) Events
order by
		WeightClass
		, Wrestler
		, eventdate desc
		, Sort desc
