
if object_id('tempdb..#LastFlo') is not null
	drop table #LastFlo

if object_id('tempdb..#LastTrack') is not null
	drop table #LastTrack

if object_id('tempdb..#Rankings') is not null
	drop table #Rankings

select	WrestlerID
		, WrestlerName
		, TeamName
		, WeightClass
		, MeetName
		, MeetDate
into	#LastFlo
from	(
		select	WrestlerID = FloWrestler.ID
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, TeamName = FloWrestler.TeamName
				, FloMatch.WeightClass
				, FloMeet.MeetName
				, MeetDate = cast(FloMeet.StartTime as date)
				, RowFilter = row_number() over (partition by FloWrestler.ID order by FloMeet.StartTime desc)
				, Wins = count(distinct case when FloWrestlerMatch.IsWinner = 1 then FloMatch.ID else null end)
				, Losses = count(distinct case when FloWrestlerMatch.IsWinner = 0 then FloMatch.ID else null end)
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
				and FloMeet.LocationState = 'sc'
				and FloMeet.StartTime > getdate() - 365
				-- and FloWrestler.id = 21908
		group by
				FloMatch.WeightClass
				, FloMeet.MeetName
				, cast(FloMeet.StartTime as date)
				, FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestler.TeamName
				, FloMeet.StartTime
		) LastEvent
where	LastEvent.RowFilter = 1

select	WrestlerID
		, WrestlerName
		, TeamName
		, WeightClass
		, MeetName
		, MeetDate
into	#LastTrack
from	(
		select	WrestlerID = TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, TrackWrestler.TeamName
				, TrackMatch.WeightClass
				, MeetName = TrackEvent.EventName
				, MeetDate = cast(TrackEvent.EventDate as date)
				, RowFilter = row_number() over (partition by TrackWrestler.ID order by TrackEvent.EventDate desc)
		from	TrackWrestler
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
				and TrackEvent.EventState = 'sc'
				and TrackEvent.EventDate > getdate() - 180
		group by
				TrackMatch.WeightClass
				, TrackEvent.EventName
				, cast(TrackEvent.EventDate as date)
				, TrackWrestler.ID
				, TrackWrestler.WrestlerName
				, TrackWrestler.TeamName
				, TrackEvent.EventDate
		) LastEvent
where	LastEvent.RowFilter = 1

select	WeightClass = LastMatch.WeightClass
		, Rank = rank() over (partition by LastMatch.WeightClass order by RatingCalc.conservativerating desc)
		, Wrestler = LastMatch.WrestlerName
		, Team = LastMatch.TeamName
		, Confrence = coalesce(TeamRank.Confrence, WrestlerRank.Confrence)
		, SCMat = WrestlerRank.Ranking
		, Rating = round(FloWrestler.GRating, 0)
		, Confidence = round(FloWrestler.GDeviation, 0)
		, LastEvent = LastMatch.MeetName
		, LastMatch.FloID
into	#Rankings
from	(
		select	WrestlerName
				, TeamName
				, WeightClass
				, MeetDate
				, MeetName
				, RowFilter = row_number() over (partition by WrestlerName order by MeetDate desc)
				, FloID = max(case when isflo = 1 then WrestlerID else null end) over (partition by WrestlerName, teamname)
		from	(
				select	WrestlerID
						, WrestlerName
						, TeamName
						, WeightClass
						, MeetDate
						, MeetName
						, IsFlo = 1
				from	#LastFlo LastFlo
				union
				select	WrestlerID
						, WrestlerName
						, TeamName
						, WeightClass
						, MeetDate
						, MeetName
						, IsFlo = 0
				from	#LastTrack LastTrack
				) Wrestler
		where	isnumeric(Wrestler.WeightClass) = 1
		) LastMatch
join	FloWrestler
on		LastMatch.FloID = FloWrestler.ID
cross apply (
		select	FloWrestler.GRating - (3 * FloWrestler.GDeviation) ConservativeRating
		) RatingCalc
left join
		TeamRank
on		LastMatch.TeamName = TeamRank.TeamName
		and TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
left join
		WrestlerRank
on		LastMatch.WrestlerName = WrestlerRank.FirstName +  ' ' + WrestlerRank.LastName
		and WrestlerRank.SourceDate = (select max(SourceDate) from WrestlerRank)
where	LastMatch.RowFilter = 1
order by
		LastMatch.WeightClass
		, rank

select	*
from	#Rankings
where	WeightClass in ('106', '113', '120')
		or FloID in (724, 21908, 28194, 8145)
		-- or Wrestler like 'ja% nathan'
		-- or Wrestler like 'j% stock%'
		-- and Confrence = '5a'
		-- or FloID = 21908
order by
		rank

return;

select * from #Rankings where Wrestler like '% nathan%'

select	TeamLineup.WeightClass
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, Rankings.Rank
		, Rating = round(FloWrestler.GRating, 0)
		, Confidence = round(FloWrestler.GDeviation, 0)
from	xx_TeamLineup TeamLineup
left join
		FloWrestler
on		TeamLineup.FloWrestlerID = FloWrestler.ID
left join
		#Rankings Rankings
on		TeamLineup.WeightClass = Rankings.WeightClass
		and TeamLineup.FloWrestlerID = Rankings.FloID
where	TeamLineup.TeamName = 'chester'
order by
		TeamLineup.WeightClass


select	WeightClass
		, Rank
		, Wrestler
		, Team
		, [Event] = cast(datepart(month, EventDate) as varchar(max)) + '/' + cast(datepart(day, EventDate) as varchar(max)) + '/' + cast(datepart(year, EventDate) as varchar(max)) + ': ' + [Event]
		, RoundName
		, Result
		, Vs
		, Change
from	(
		select	WeightClass = Rankings.WeightClass
				, Rankings.Rank
				, Rankings.Team
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
				, Vs = Opponent.FirstName + ' ' + Opponent.LastName + ' / ' + OpponentMatch.Team + ' (' + cast(cast(coalesce(OpponentRating.Rating, 0) as int) as varchar(max)) + ')'
				, Change = cast(cast(round(WrestlerRating.Rating, 0) as int) as varchar(max)) + ' (' + cast(cast(round(WrestlerRating.Rating - WrestlerRating.InitialRating, 0) as int) as varchar(max)) + ')'
				, FloMatch.Sort
				, MatchID = FloMatch.ID
		from	#Rankings Rankings
		join	FloWrestler
		on		Rankings.FloID = FloWrestler.ID
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
						, InitialRating = TSMatch.RatingInitial
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
				and (
					Rankings.WeightClass = '106'
					or Rankings.FloID in (724, 21908, 28194)
				)
		union all
		select	WeightClass = Rankings.WeightClass
				, Rankings.Rank
				, Rankings.Team
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
				, Vs = Opponent.WrestlerName + ' / ' + OpponentMatch.Team + ' (' + cast(cast(coalesce(OpponentRating.Rating, 0) as int) as varchar(max)) + ')'
				, Change = cast(cast(round(WrestlerRating.Rating, 0) as int) as varchar(max)) + ' (' + cast(cast(round(WrestlerRating.Rating - WrestlerRating.InitialRating, 0) as int) as varchar(max)) + ')'
				, TrackMatch.Sort
				, MatchID = TrackMatch.ID
		from	#Rankings Rankings
		join	FloWrestler
		on		Rankings.FloID = FloWrestler.ID
		join	TrackWrestler
		on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
		join	TrackWrestlerMatch
		on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
		outer apply (
				select	Rating = TSMatch.RatingUpdate
						, InitialRating = TSMatch.RatingInitial
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
				and (
					Rankings.WeightClass = '106'
					or Rankings.FloID in (724, 21908, 28194)
				)
				-- and TrackMatch.WinType is not null
				and coalesce(TrackMatch.WinType, '') <> 'bye'
		) Events
order by
		WeightClass
		, Rank
		, Wrestler
		, eventdate desc
		, Sort desc


select * from #Rankings where Wrestler = 'aiden johnson'

select	*
from	#LastFlo
where	WrestlerName = 'Aiden Johnson'
