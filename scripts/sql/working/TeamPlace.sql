
declare @LastWeek int;
declare @Year int;

select	@LastWeek = datepart(week, getdate()) - 1
		, @Year = datepart(year, getdate());

select	*
from	(
		select	EventName = FloMeet.MeetName
				, Place = max(case 
						when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 1 then '1st'
						when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 0 then '2nd'
						when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 1 then '3rd'
						when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 0 then '4th'
						when FloMatch.RoundName = '5th Place' and FloWrestlerMatch.IsWinner = 1 then '5th'
						when FloMatch.RoundName = '5th Place' and FloWrestlerMatch.IsWinner = 0 then '6th'
						else null end
					)
				, WeightClass = max(FloMatch.WeightClass)
				, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		from	FloWrestlerMatch
		join	FloWrestler
		on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestlerMatch.Team like 'fort mill%'
				and datepart(week, FloMeet.StartTime) = @LastWeek
				and datepart(year, FloMeet.StartTime) = @Year
		group by
				FloWrestler.FirstName + ' ' + FloWrestler.LastName
				, FloMeet.MeetName
		) FMEvents
where	Place is not null
order by
		EventName
		, Place
		, cast(WeightClass as int)
