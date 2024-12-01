
select	*
from	FloMeet
where	ModifiedDate > getdate() - 1

select	FloMatch.Division
		-- , FloMatch.WeightClass
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, Place = min(case 
			when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 1 then '1st' 
			when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 0 then '2nd' 
			when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 1 then '3rd' 
			when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 0 then '4th' 
			else 'DnP' end)
		, Wins = sum(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end)
		-- , Losses = sum(case when FloWrestlerMatch.IsWinner = 0 then 1 else 0 end)
		-- , Matches = count(distinct FloMatch.ID)
		-- , [Percentage] = cast(sum(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end) as decimal(9,2)) / cast(count(distinct FloMatch.ID) as decimal(9,2))
		, Pins = sum(case when FloWrestlerMatch.IsWinner = 1 and FloMatch.WinType = 'f' then 1 else 0 end)
		, TechFalls = sum(case when FloWrestlerMatch.IsWinner = 1 and FloMatch.WinType = 'tf' then 1 else 0 end)
		, Majors = sum(case when FloWrestlerMatch.IsWinner = 1 and FloMatch.WinType = 'md' then 1 else 0 end)
		, Minors = sum(case when FloWrestlerMatch.IsWinner = 1 and FloMatch.WinType = 'dec' then 1 else 0 end)
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
		and FloMatch.WinType <> 'BYE'
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
		and FloWrestlerMatch.Team = 'fort mill'
join	FloWrestler
on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
where	FloMeet.ID = 21878
		and FloMatch.Division = 'HS'
group by
		FloMatch.Division
		, FloMatch.WeightClass
		, FloWrestler.FirstName
		, FloWrestler.LastName
order by
		Place
		, wins desc



select	TrackMatch.Division
		, TrackMatch.WeightClass
		, Wrestler = TrackWrestler.WrestlerName
		, Place = min(case 
			when TrackMatch.RoundName = 'Finals' and TrackWrestlerMatch.IsWinner = 1 then '1st' 
			when TrackMatch.RoundName = 'Finals' and TrackWrestlerMatch.IsWinner = 0 then '2nd' 
			when TrackMatch.RoundName = '3rd Place' and TrackWrestlerMatch.IsWinner = 1 then '3rd' 
			when TrackMatch.RoundName = '3rd Place' and TrackWrestlerMatch.IsWinner = 0 then '4th' 
			else 'DnP' end)
		, Wins = sum(case when TrackWrestlerMatch.IsWinner = 1 then 1 else 0 end)
		, Losses = sum(case when TrackWrestlerMatch.IsWinner = 0 then 1 else 0 end)
		, Matches = count(distinct TrackMatch.ID)
		, [Percentage] = cast(sum(case when TrackWrestlerMatch.IsWinner = 1 then 1 else 0 end) as decimal(9,2)) / cast(count(distinct TrackMatch.ID) as decimal(9,2))
		, Pins = sum(case when TrackWrestlerMatch.IsWinner = 1 and TrackMatch.WinType = 'f' then 1 else 0 end)
		, TechFalls = sum(case when TrackWrestlerMatch.IsWinner = 1 and TrackMatch.WinType = 'tf' then 1 else 0 end)
		, Majors = sum(case when TrackWrestlerMatch.IsWinner = 1 and TrackMatch.WinType = 'md' then 1 else 0 end)
		, Minors = sum(case when TrackWrestlerMatch.IsWinner = 1 and TrackMatch.WinType = 'dec' then 1 else 0 end)
from	TrackEvent
join	TrackMatch
on		TrackEvent.ID = TrackMatch.TrackEventID
		and TrackMatch.WinType <> 'BYE'
join	TrackWrestlerMatch
on		TrackMatch.ID = TrackWrestlerMatch.TrackMatchID
join	TrackWrestler
on		TrackWrestlerMatch.TrackWrestlerID = TrackWrestler.ID
where	TrackEvent.ID = 10188
		and TrackWrestlerMatch.Team = 'indian land'
		-- and TrackMatch.Division = 'HS'
group by
		TrackMatch.Division
		, TrackMatch.WeightClass
		, TrackWrestler.WrestlerName
order by
		Place
		, wins desc
