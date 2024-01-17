
if object_id('tempdb..#wrestlers') is not null
	drop table #Wrestlers

select	WrestlerID = row_number() over (order by coalesce(max(wrestlers.FloWrestlerID), max(wrestlers.TrackWrestlerID)))
		, FloWrestlerID = max(wrestlers.FloWrestlerID)
		, TrackWrestlerID = max(wrestlers.TrackWrestlerID)
		, Wrestlers.WrestlerName
		, GRating = max(Wrestlers.Rating)
		, GDeviation = max(Wrestlers.Deviation)
into	#Wrestlers
from	(
		select	FloWrestlerMatch.FloWrestlerID
				, TrackWrestlerID = cast(null as int)
				, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, Rating = cast(FloWrestler.GRating as int)
				, Deviation = cast(FloWrestler.GDeviation as int)
		from	FloWrestlerMatch
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		where	FloWrestlerMatch.team = 'rock hill'
		union
		select	FloWrestlerID = cast(null as int)
				, TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				, WrestlerName = TrackWrestler.WrestlerName
				, Rating = cast(null as int)
				, Deviation = cast(null as int)
		from	TrackWrestlerMatch
		join	TrackWrestler
		on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
		where	TrackWrestlerMatch.team = 'rock hill'
		) Wrestlers
group by
		Wrestlers.WrestlerName;

select	LastMatch.WeightClass
		, LastMatch.Division
		, Wrestlers.WrestlerName
		, Wrestlers.GRating
		, wrestlers.GDeviation
		, wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
		, Events = string_agg(cast(AllMatches.EventDate as varchar(max)) + ': ' + AllMatches.EventName, '; ') 
			within group (order by AllMatches.EventDate desc)
from	#wrestlers Wrestlers
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
				from	#Wrestlers Wrestlers
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
				from	#Wrestlers Wrestlers
				join	TrackWrestlerMatch
				on		Wrestlers.TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
				join	TrackMatch
				on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
				join	TrackEvent
				on		TrackMatch.TrackEventID = TrackEvent.ID
				) AllMatches
		) LastMatch
on		wrestlers.WrestlerID = LastMatch.WrestlerID
join	(
		select	Wrestlers.WrestlerID
				, EventDate = cast(FloMeet.StartTime as date)
				, EventName = FloMeet.MeetName
		from	#Wrestlers Wrestlers
		join	FloWrestlerMatch
		on		Wrestlers.FloWrestlerID = FloWrestlerMatch.FloWrestlerID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		group by
				Wrestlers.WrestlerID
				, cast(FloMeet.StartTime as date)
				, FloMeet.MeetName
		union
		select	Wrestlers.WrestlerID
				, EventDate = cast(TrackEvent.EventDate as date)
				, EventName = TrackEvent.EventName
		from	#Wrestlers Wrestlers
		join	TrackWrestlerMatch
		on		Wrestlers.TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		group by
				Wrestlers.WrestlerID
				, cast(TrackEvent.EventDate as date)
				, TrackEvent.EventName
		) AllMatches
on		Wrestlers.WrestlerID = AllMatches.WrestlerID
where	LastMatch.RowFilter = 1
group by
		LastMatch.WeightClass
		, LastMatch.Division
		, LastMatch.EventDate
		, Wrestlers.WrestlerName
		, Wrestlers.GRating
		, wrestlers.GDeviation
		, wrestlers.FloWrestlerID
		, Wrestlers.TrackWrestlerID
order by
		case when isnumeric(LastMatch.WeightClass) = 1 then cast(LastMatch.WeightClass as int) else 999 end
		, LastMatch.WeightClass
		, coalesce(LastMatch.Division, 'zzzz')
		, LastMatch.EventDate desc
		, Wrestlers.GRating desc

return;

insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '106', 106598);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '113', 106604);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '120', 871);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '126', 910);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '132', 96978);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '138', 25160);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '144', 104769);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '150', 21768);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '157', 8203);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '165', 978);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '175', 104780);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '190', 993);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '215', 1013);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Rock Hill', '285', 18019);

select	TeamLineup.ID
		, TeamLineup.WeightClass
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, TeamLineup.FloWrestlerID
		, FloWrestler.GRating
		, FloWrestler.GDeviation
from	xx_TeamLineup TeamLineup
left join
		FloWrestler
on		TeamLineup.FloWrestlerID = FloWrestler.ID
where	TeamLineup.TeamName = 'rock hill'
order by
		cast(TeamLineup.WeightClass as int)

select	*
from	xx_TeamLineup
where	TeamName = 'fort mill'
		and WeightClass = '144'

update	xx_TeamLineup
set		FloWrestlerID = 56835
where	id = 196

-- delete from xx_TeamLineup where teamname = 'Blythewood'
