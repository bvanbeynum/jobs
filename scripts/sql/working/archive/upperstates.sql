
select	*
from	FloMeet
where	MeetName like '2024% schsl% 5a% upper%'

select	*
from	TrackWrestler
where	1 = 1
		and WrestlerName like 'mic% hall%'

select	*
from	TSWrestler
where	FloWrestlerID = 8145
		and TSSummaryID = 51

select	Rank = rank() over (order by WrestlerRank.conservativerating desc)
		, FloWrestler.id
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, WrestlerRank.ConservativeRating
		, FloWrestler.GRating
		, FloWrestler.GDeviation
from	FloMatch
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
join	FloWrestler
on		FloWrestlerMatch.FloWrestlerID = FloWrestler.ID
outer apply (
		select	ConservativeRating = FloWrestler.GRating - (3 * FloWrestler.GDeviation)
		) WrestlerRank
where	FloMatch.FloMeetID = 13127
		and FloMatch.WeightClass = '106'
		-- and FloWrestler.LastName = 'nally'
group by
		FloWrestler.id
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.TeamName
		, WrestlerRank.ConservativeRating
		, FloWrestler.GRating
		, FloWrestler.GDeviation
order by
		Rank

select * from flowrestler where firstname = 'Aiden' and lastname = 'Johnson' -- 869
select * from flowrestler where firstname = 'Bryson' and lastname = 'Hipps' -- 7652
select * from flowrestler where firstname = 'Calvin' and lastname = 'Cook' -- 81085
select * from flowrestler where firstname = 'Cj' and lastname = 'Williams' -- 3004
select * from flowrestler where firstname = 'Dillan' and lastname = 'Boyer' -- 81442
select * from flowrestler where firstname = 'Harrison' and lastname = 'Knight' -- 81215
select * from flowrestler where firstname = 'Jace' and lastname = 'Randolph' -- 43673
select * from flowrestler where firstname = 'Jalan' and lastname = 'Esquivel' -- 3031
select * from flowrestler where firstname = 'Jessiah' and lastname = 'Rockeymore' -- 104744
select * from flowrestler where firstname = 'Lex' and lastname = 'Abernathy' -- 724
select * from flowrestler where firstname = 'Luke' and lastname = 'Hillers' -- 81084
select * from flowrestler where firstname = 'Lucas' and lastname = 'Van Beynum' -- 8145
select * from flowrestler where firstname = 'Luke' and lastname = 'Hudson' -- 94068
select * from flowrestler where firstname = 'Micah' and lastname = 'Hall' -- 872
select * from flowrestler where firstname = 'Ryan' and lastname = 'Mcgrail' -- 3019

select * from TrackWrestler where WrestlerName = 'Aiden Johnson' --
select * from TrackWrestler where WrestlerName = 'Bryson Hipps' -- 68881
select * from TrackWrestler where WrestlerName = 'Calvin Cook' --
select * from TrackWrestler where WrestlerName = 'Cj Williams' -- 4428
select * from TrackWrestler where WrestlerName = 'Dillan Boyer' -- 68885
select * from TrackWrestler where WrestlerName = 'Harrison Knight' --
select * from TrackWrestler where WrestlerName = 'Jace Randolph' -- 933
select * from TrackWrestler where WrestlerName = 'Jalan Esquivel' -- 51885
select * from TrackWrestler where WrestlerName = 'Jessiah Rockeymore' -- 51730
select * from TrackWrestler where WrestlerName = 'Lex Abernathy' -- 11834
select * from TrackWrestler where WrestlerName = 'Luke Hillers' -- 6461
select * from TrackWrestler where WrestlerName = 'Lucas Van Beynum' -- 940
select * from TrackWrestler where WrestlerName = 'Luke Hudson' -- 3338
select * from TrackWrestler where WrestlerName = 'Micah Hall' -- 943
select * from TrackWrestler where WrestlerName = 'Ryan Mcgrail' -- 81794

select	Rank = rank() over (order by WrestlerRank.conservativerating desc)
		, id
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, WrestlerRank.ConservativeRating
		, FloWrestler.GRating
		, FloWrestler.GDeviation
from	FloWrestler
cross apply (
		select	ConservativeRating = FloWrestler.GRating - (3 * FloWrestler.GDeviation)
		) WrestlerRank
where	id in (869, 7652, 81085, 3004, 81442, 81215, 43673, 3031, 104744, 724, 81084, 8145, 94068, 872, 3019)
order by
		rank
