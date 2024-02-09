
return;

select distinct teamname from xx_TeamLineup order by TeamName

select * from TeamRank where TeamName = 'clover' and SourceDate = (select max(SourceDate) from TeamRank)

select	OtherTeam.TeamName
		, Wrestlers = count(distinct FloWrestler.ID)
from	FloWrestler
join	FloWrestler OtherTeam
on		FloWrestler.FirstName = OtherTeam.FirstName
		and FloWrestler.LastName = OtherTeam.LastName
		and FloWrestler.TeamName <> OtherTeam.TeamName
where	FloWrestler.TeamName = 'Stratford'
group by
		OtherTeam.TeamName
order by
		Wrestlers desc

select	*
from	(
		select	WrestlerWeight = case when coalesce(Flo.MatchDate, '1/1/1900') > coalesce(Track.MatchDate, '1/1/1900') then Flo.WeightClass else Track.WeightClass end
				-- , AllWrestlers.FloWrestlerID
				-- , AllWrestlers.TrackWrestlerID
				, AllWrestlers.WrestlerName
				, WrestlerDivision = case when coalesce(Flo.MatchDate, '1/1/1900') > coalesce(Track.MatchDate, '1/1/1900')  then Flo.Division else Track.Division end
				, Ranking = AllWrestlers.GRating
				, Deviation = AllWrestlers.GDeviation
				-- , IsLastFlo = case when coalesce(Flo.MatchDate, '1/1/1900') > coalesce(Track.MatchDate, '1/1/1900')  then 1 else 0 end
				, EventName = case when coalesce(Flo.MatchDate, '1/1/1900') > coalesce(Track.MatchDate, '1/1/1900')  then Flo.EventName else Track.EventName end
				, LastDate = case when coalesce(Flo.MatchDate, '1/1/1900') > coalesce(Track.MatchDate, '1/1/1900')  then Flo.MatchDate else Track.MatchDate end
		from	(
				select	FloWrestlerID = max(wrestlers.FloWrestlerID)
						, TrackWrestlerID = max(wrestlers.TrackWrestlerID)
						, Wrestlers.WrestlerName
						, GRating = max(Wrestlers.GRating)
						, GDeviation = max(Wrestlers.GDeviation)
				from	(
						select	FloWrestlerID = FloWrestler.ID
								, TrackWrestlerID = cast(null as int)
								, WrestlerName = FloWrestler.FirstName + ' ' + FloWrestler.LastName
								, GRating = cast(round(FloWrestler.GRating, 0) as int)
								, GDeviation = cast(round(FloWrestler.GDeviation, 0) as int)
						from	FloWrestler
						where	FloWrestler.TeamName = 'Blythewood'
						union
						select	FloWrestlerID = cast(null as int)
								, TrackWrestlerID = TrackWrestler.ID
								, TrackWrestler.WrestlerName
								, GRating = cast(null as int)
								, GDeviation = cast(null as int)
						from	TrackWrestler
						where	TrackWrestler.TeamName = 'Blythewood'
						) Wrestlers
				group by
						Wrestlers.WrestlerName
				) AllWrestlers
		outer apply (
				select	top 1
						Division = case
							when FloMatch.Division in ('high school', 'hs', 'high', 'girls') then 'Varsity'
							when FloMatch.Division in ('junior varsity', 'jr varsity') then 'JV'
							when FloMatch.Division in ('middle school', 'middle') then 'MS'
							else FloMatch.Division end
						, FloMatch.WeightClass
						, MatchDate = cast(FloMeet.StartTime as date)
						, EventName = FloMeet.MeetName
				from	FloWrestlerMatch
				join	FloMatch
				on		FloWrestlerMatch.FloMatchID = FloMatch.ID
				join	FloMeet
				on		FloMatch.FloMeetID = FloMeet.ID
				where	AllWrestlers.FloWrestlerID = FloWrestlerMatch.FloWrestlerID
						-- and isnumeric(FloMatch.WeightClass) = 1
				order by
						FloMeet.StartTime desc
				) Flo
		outer apply (
				select	top 1
						Division = case
							when TrackMatch.Division in ('high school', 'hs', 'high', 'girls') then 'Varsity'
							when TrackMatch.Division in ('junior varsity', 'jr varsity') then 'JV'
							when TrackMatch.Division in ('middle school', 'middle') then 'MS'
							else TrackMatch.Division end
						, TrackMatch.WeightClass
						, MatchDate = cast(TrackEvent.EventDate as date)
						, EventName = TrackEvent.EventName
				from	TrackWrestler
				join	TrackWrestlerMatch
				on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
				join	TrackMatch
				on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
				join	TrackEvent
				on		TrackMatch.TrackEventID = TrackEvent.ID
				where	AllWrestlers.TrackWrestlerID = TrackWrestler.ID
						-- and isnumeric(FloMatch.WeightClass) = 1
				order by
						TrackEvent.EventDate desc
				) Track
		) WrestlerData
order by
		isnumeric(WrestlerWeight) desc
		, coalesce(WrestlerWeight, 'zzzz')
		, case when WrestlerDivision in ('varsity', 'high school') then 1
			when WrestlerDivision in ('jv', 'junior varsity', 'jr varsity') then 2
			else 3 end
		, LastDate desc
		, Ranking desc
		, WrestlerName


insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '106', 94068);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '113', 25349);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '120', 25152);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '126', 864);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '132', 5320);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '138', 25180);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '144', 5350);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '150', 932);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '157', 965);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '165', 991);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '175', 982);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '190', 99588);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '215', 1039);
insert xx_TeamLineup (TeamName, WeightClass, FloWrestlerID) values ('Clover', '285', 28377);

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
where	TeamLineup.TeamName = 'Clover'
order by
		cast(TeamLineup.WeightClass as int)

select	*
from	xx_TeamLineup
where	TeamName = 'fort mill'
		and WeightClass = '144'

update	xx_TeamLineup
set		FloWrestlerID = 1695
where	id = 69

-- delete from xx_TeamLineup where teamname = 'Blythewood'

select * from xx_TeamLineup
