
if object_id('tempdb..#wrestlers') is not null
	drop table #Wrestlers

declare @Team varchar(255)
set @Team = 'Goose Creek'

select	WrestlerID = row_number() over (order by coalesce(max(wrestlers.FloWrestlerID), max(wrestlers.TrackWrestlerID)))
		, FloWrestlerID = min(wrestlers.FloWrestlerID)
		, TrackWrestlerID = min(wrestlers.TrackWrestlerID)
		, Wrestlers.WrestlerName
		, GRating = string_agg(Wrestlers.Rating, ', ')
		, GDeviation = string_agg(Wrestlers.Deviation, ', ')
		, AllFlo = string_agg(wrestlers.FloWrestlerID, ', ')
		, AllTrack = string_agg(wrestlers.TrackWrestlerID, ', ')
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
		Wrestlers.WrestlerName;

select	LastMatch.WeightClass
		, LastMatch.Division
		, Wrestlers.WrestlerName
		, Wrestlers.GRating
		, wrestlers.GDeviation
		-- , wrestlers.AllFlo
		-- , Wrestlers.AllTrack
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
		, wrestlers.AllFlo
		, Wrestlers.AllTrack
order by
		case when isnumeric(LastMatch.WeightClass) = 1 then cast(LastMatch.WeightClass as int) else 999 end
		, LastMatch.WeightClass
		, coalesce(LastMatch.Division, 'zzzz')
		, LastMatch.EventDate desc
		, Wrestlers.GRating desc

return;

select	FloMeet.StartTime
		, FloMeet.MeetName
		, FloMatch.WeightClass
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestlerMatch.FloWrestlerID
from	FloWrestlerMatch
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
join	FloWrestler
on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
where	FloWrestlerMatch.Team = 'Boiling Springs'
		and FloMeet.MeetName like '2024 rock hill%'
group by
		FloMeet.StartTime
		, FloMeet.MeetName
		, FloMatch.WeightClass
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestlerMatch.FloWrestlerID
order by
		case when isnumeric(FloMatch.WeightClass) = 1 then cast(FloMatch.WeightClass as int) else FloMatch.WeightClass end

insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '106', 25346);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '113', 79318);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '120', 80606);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '126', 106617);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '132', 25206);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '138', 21957);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '144', 25224);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '150', 22040);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '157', 21991);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '165', 56576);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '175', 105829);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '190', 80645);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '215', 80643);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Goose Creek', '285', 27971);

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

select	TeamName
		, Wrestlers = count(distinct TeamLineup.FloWrestlerID)
from	xx_TeamLineup TeamLineup
group by
		TeamName
order by
		TeamName

select	*
from	xx_TeamLineup
where	TeamName = 'byrnes'
		and WeightClass = '215'

update	xx_TeamLineup
set		FloWrestlerID = 1021
where	id = 203

select * from xx_TeamLineup where id = 1215

-- delete from xx_TeamLineup where teamname = 'Blythewood'
