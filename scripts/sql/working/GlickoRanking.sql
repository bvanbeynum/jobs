
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
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
				and FloMeet.LocationState = 'sc'
				and FloMeet.StartTime > getdate() - 180
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
				, FloID = max(case when isflo = 1 then WrestlerID else null end) over (partition by WrestlerName)
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
where	WeightClass = '106'
		-- and Confrence = '5a'
order by
		rank

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

select	Rankings.WeightClass
		, Rankings.Rank
		, Rankings.Wrestler
		, Rankings.Team
		, [Event] = coalesce(FloEvent.EventName, TrackEvent.EventName)
		, TSMatch.IsWinner
		, Vs = OtherWrestler.Wrestler + ' (' + cast(cast(round(OtherWrestler.Rating, 0) as int) as varchar(max)) + ')'
		, Change = cast(cast(round(TSMatch.RatingUpdate, 0) as int) as varchar(max)) + ' (' + cast(cast(round(TSMatch.RatingUpdate - TSMatch.RatingInitial, 0) as int) as varchar(max)) + ')'
from	#Rankings Rankings
join	TSWrestler
on		Rankings.FloID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = 44
join	TSMatch
on		TSWrestler.ID = TSMatch.TSWrestlerID
cross apply (
		select	Wrestler = coalesce(FloWrestler.FirstName + ' ' + FloWrestler.LastName, TrackWrestler.WrestlerName)
				, Rating = OtherMatch.RatingInitial
		from	TSMatch OtherMatch
		join	TSWrestler OtherWrestler
		on		OtherMatch.TSWrestlerID = OtherWrestler.ID
		left join
				FloWrestler
		on		OtherWrestler.FloWrestlerID = FloWrestler.ID
		left join
				TrackWrestler
		on		OtherWrestler.TrackWrestlerID = TrackWrestler.ID
		where	TSMatch.MatchID = OtherMatch.MatchID
				and TSMatch.IsFlo = OtherMatch.IsFlo
				and TSWrestler.TSSummaryID = OtherWrestler.TSSummaryID
				and TSWrestler.ID <> OtherMatch.TSWrestlerID
		) OtherWrestler
outer apply (
		select	EventName = FloMeet.MeetName
				, EventDate = cast(FloMeet.StartTime as date)
		from	FloMeet
		where	TSMatch.EventID = FloMeet.ID
				and TSMatch.IsFlo = 1
		) FloEvent
outer apply (
		select	EventName = TrackEvent.EventName
				, EventDate = cast(TrackEvent.EventDate as date)
		from	TrackEvent
		where	TSMatch.EventID = TrackEvent.ID
				and TSMatch.IsFlo = 0
		) TrackEvent
where	Rankings.WeightClass = '106'
		and Rankings.Confrence is not null
order by
		rankings.Rank
		, TSMatch.Sort
