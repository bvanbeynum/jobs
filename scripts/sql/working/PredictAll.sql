
declare @Team varchar(255)
set @Team = 'Summerville'

select	WrestlerID = row_number() over (order by coalesce(max(wrestlers.FloWrestlerID), max(wrestlers.TrackWrestlerID)))
		, FloWrestlerID = min(wrestlers.FloWrestlerID)
		, TrackWrestlerID = min(wrestlers.TrackWrestlerID)
		, Wrestlers.WrestlerName
into	#Opponent
from	(
		select	FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = cast(null as int)
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Rating = cast(FloWrestler.GRating as int)
				, Deviation = cast(FloWrestler.GDeviation as int)
		from	FloWrestlerMatch
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		where	FloWrestlerMatch.team = @Team
		union
		select	FloWrestlerID = cast(null as int)
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, WrestlerName = TrackWrestler.WrestlerName
				, Rating = cast(null as int)
				, Deviation = cast(null as int)
		from	TrackWrestlerMatch
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		where	TrackWrestlerMatch.team = @Team
		) Wrestlers
group by
		Wrestlers.WrestlerName
having	min(Wrestlers.FloWrestlerID) > 0


select	WrestlerID = row_number() over (order by coalesce(max(wrestlers.FloWrestlerID), max(wrestlers.TrackWrestlerID)))
		, FloWrestlerID = min(wrestlers.FloWrestlerID)
		, TrackWrestlerID = min(wrestlers.TrackWrestlerID)
		, Wrestlers.WrestlerName
into	#FM
from	(
		select	FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = cast(null as int)
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Rating = cast(FloWrestler.GRating as int)
				, Deviation = cast(FloWrestler.GDeviation as int)
		from	FloWrestlerMatch
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		where	FloWrestlerMatch.team = 'fort mill'
		union
		select	FloWrestlerID = cast(null as int)
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, WrestlerName = TrackWrestler.WrestlerName
				, Rating = cast(null as int)
				, Deviation = cast(null as int)
		from	TrackWrestlerMatch
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		where	TrackWrestlerMatch.team = 'fort mill'
		) Wrestlers
group by
		Wrestlers.WrestlerName
having	min(Wrestlers.FloWrestlerID) > 0

select	Wrestlers.WrestlerID
		, Wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
		, Wrestlers.WrestlerName
		, LastMatch.WeightClass
		, LastMatch.Division
into	#OpponentWeight
from	#Opponent Wrestlers
left join (
		select	WrestlerID
				, WeightClass
				, Division
				, EventDate
				, RowFilter = row_number() over (partition by WrestlerID order by EventDate desc)
		from	(
				select	Wrestlers.WrestlerID
						, FloMatch.WeightClass
						, FloMatch.Division
						, EventDate = FloMeet.StartTime
				from	#Opponent Wrestlers
				join	FloWrestlerMatch
				on		Wrestlers.FloWrestlerID = FloWrestlerMatch.FloWrestlerID
				join	FloMatch
				on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				join	FloMeet
				on		FloMatch.FloMeetID = FloMeet.ID
				union
				select	Wrestlers.WrestlerID
						, TrackMatch.WeightClass
						, TrackMatch.Division
						, EventDate = TrackEvent.EventDate
				from	#Opponent Wrestlers
				join	TrackWrestlerMatch
				on		Wrestlers.TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				join	TrackMatch
				on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
				join	TrackEvent
				on		TrackMatch.TrackEventID = TrackEvent.ID
				) AllMatches
		) LastMatch
on		wrestlers.WrestlerID = LastMatch.WrestlerID
where	LastMatch.RowFilter = 1
		and LastMatch.EventDate > '9/1/2023'
group by
		Wrestlers.WrestlerID
		, Wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
		, Wrestlers.WrestlerName
		, LastMatch.WeightClass
		, LastMatch.Division

select	Wrestlers.WrestlerID
		, Wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
		, Wrestlers.WrestlerName
		, LastMatch.WeightClass
		, LastMatch.Division
into	#FMWeight
from	#FM Wrestlers
left join (
		select	WrestlerID
				, WeightClass
				, Division
				, EventDate
				, RowFilter = row_number() over (partition by WrestlerID order by EventDate desc)
		from	(
				select	Wrestlers.WrestlerID
						, FloMatch.WeightClass
						, FloMatch.Division
						, EventDate = FloMeet.StartTime
				from	#FM Wrestlers
				join	FloWrestlerMatch
				on		Wrestlers.FloWrestlerID = FloWrestlerMatch.FloWrestlerID
				join	FloMatch
				on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				join	FloMeet
				on		FloMatch.FloMeetID = FloMeet.ID
				union
				select	Wrestlers.WrestlerID
						, TrackMatch.WeightClass
						, TrackMatch.Division
						, EventDate = TrackEvent.EventDate
				from	#FM Wrestlers
				join	TrackWrestlerMatch
				on		Wrestlers.TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				join	TrackMatch
				on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
				join	TrackEvent
				on		TrackMatch.TrackEventID = TrackEvent.ID
				) AllMatches
		) LastMatch
on		wrestlers.WrestlerID = LastMatch.WrestlerID
where	LastMatch.RowFilter = 1
		and LastMatch.EventDate > '9/1/2023'
group by
		Wrestlers.WrestlerID
		, Wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
		, Wrestlers.WrestlerName
		, LastMatch.WeightClass
		, LastMatch.Division

select	*
from	#OpponentWeight

select	*
from	#FMWeight


select	TeamLineup.WeightClass
		, TeamLineup.Division
		, FMWrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName  + case when TSWrestler.Rating = 1500 and TSWrestler.Deviation = 450 then '' else ' (' + cast(cast(TSWrestler.Rating as int) as varchar(max)) + ')' end
		, OpponentWeight.WeightClass
		, OpponentWeight.Division
		, OpponentWrestler = OpponentWeight.WrestlerName + case when TSOpponent.Rating = 1500 and TSOpponent.Deviation = 450 then '' else ' (' + cast(cast(TSOpponent.Rating as int) as varchar(max)) + ')' end
		, case when (TSOpponent.Rating = 1500 and TSOpponent.Deviation = 450) or (TSWrestler.Rating = 1500 and TSWrestler.Deviation = 450) then '?' else cast(round(GlickoPrediction.Probability * 100, 2) as varchar(max)) + '%' end
from	#FMWeight TeamLineup
join	FloWrestler
on		TeamLineup.FloWrestlerID = FloWrestler.ID
left join
		TSWrestler
on		TeamLineup.FloWrestlerID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
join	(
		select	PrevWeight = lag(WeightClass) over (order by WeightClass)
				, WeightClass
				, NextWeight = lead(WeightClass) over (order by WeightClass)
		from	xx_TeamLineup
		group by
				WeightClass
		) WeightTable
on		TeamLineup.WeightClass = WeightTable.WeightClass
left join
		#OpponentWeight	OpponentWeight
on		WeightTable.WeightClass = OpponentWeight.WeightClass
		or WeightTable.PrevWeight = OpponentWeight.WeightClass
		or WeightTable.NextWeight = OpponentWeight.WeightClass
left join
		TSWrestler TSOpponent
on		OpponentWeight.FloWrestlerID = TSOpponent.FloWrestlerID
		and TSOpponent.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
left join
		GlickoPrediction
on		TeamLineup.FloWrestlerID = GlickoPrediction.Wrestler1FloID
		and OpponentWeight.FloWrestlerID = GlickoPrediction.Wrestler2FloID
-- where	TeamLineup.TeamName = 'fort mill'
		-- and TeamLineup.WeightClass = '106'
order by
		TeamLineup.WeightClass
		, TeamLineup.Division desc
		, TSWrestler.Rating desc
		, FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, OpponentWeight.WeightClass
		, TSOpponent.Rating desc
