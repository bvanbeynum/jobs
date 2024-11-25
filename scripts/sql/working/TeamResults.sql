
select	*
from	FloMeet
where	ModifiedDate > getdate() - 1

select	FloMatch.Division
		, FloMatch.WeightClass
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, Wins = sum(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end)
		, Losses = sum(case when FloWrestlerMatch.IsWinner = 0 then 1 else 0 end)
		, Matches = count(distinct FloMatch.ID)
		, [Percentage] = cast(sum(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end) as decimal(9,2)) / cast(count(distinct FloMatch.ID) as decimal(9,2))
		, Place = min(case 
			when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 1 then '1st' 
			when FloMatch.RoundName = 'Finals' and FloWrestlerMatch.IsWinner = 0 then '2nd' 
			when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 1 then '3rd' 
			when FloMatch.RoundName = '3rd Place' and FloWrestlerMatch.IsWinner = 0 then '4th' 
			else 'DnP' end)
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
group by
		FloMatch.Division
		, FloMatch.WeightClass
		, FloWrestler.FirstName
		, FloWrestler.LastName
order by
		Place
		, [Percentage] desc