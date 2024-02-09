
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
where	FloMatch.FloMeetID = 11573
		and FloMatch.WeightClass = '113'
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

select * from flowrestler where firstname = 'Adam' and lastname = 'Hardeman' -- 102911
select * from flowrestler where firstname = 'Aiden' and lastname = 'Simmons' -- 93242
select * from flowrestler where firstname = 'Andreo' and lastname = 'Manlove' -- 89170
select * from flowrestler where firstname = 'Brock' and lastname = 'Watson' -- 102920
select * from flowrestler where firstname = 'Caeden' and lastname = 'Carr' -- 80663
select * from flowrestler where firstname = 'Caleb' and lastname = 'Mcternan' -- 80479
select * from flowrestler where firstname = 'Colton' and lastname = 'Creswell' -- 99333
select * from flowrestler where firstname = 'Eddy' and lastname = 'Yambao' -- 102916
select * from flowrestler where firstname = 'Evan' and lastname = 'Gates' -- 101906
select * from flowrestler where firstname = 'Jack' and lastname = 'Turner' -- 80981
select * from flowrestler where firstname = 'Jantzen' and lastname = 'Huneycutt' -- 30649
select * from flowrestler where firstname = 'Jaylen' and lastname = 'phillips' -- 102086
select * from flowrestler where firstname = 'Landon' and lastname = 'Phillips' -- 52047
select * from flowrestler where firstname = 'luke' and lastname = 'VAN BEYNUM' -- 8145
select * from flowrestler where firstname = 'Luke' and lastname = 'Hudson' -- 94068
select * from flowrestler where firstname = 'Mitch' and lastname = 'Wells' -- 102919
select * from flowrestler where firstname = 'Nick' and lastname = 'Velez' -- 102913
select * from flowrestler where firstname = 'Oscar' and lastname = 'Roman' -- 102085
select * from flowrestler where firstname = 'Porter' and lastname = 'Seay' -- 98456
select * from flowrestler where firstname = 'Roland' and lastname = 'Preston' -- 101971
select * from flowrestler where firstname = 'Ryan' and lastname = 'Seman' -- 101970
select * from flowrestler where firstname = 'Sullivan' and lastname = 'Silbiger' -- 80667
select * from flowrestler where firstname = 'Taylor' and lastname = 'Reed' -- 56538
select * from flowrestler where firstname = 'Timothy' and lastname = 'Jackson' -- 100420

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
where	id in (102911, 93242, 89170, 102920, 80663, 80479, 99333, 102916, 101906, 80981, 30649, 102086, 52047, 8145, 94068, 102919, 102913, 102085, 98456, 101971, 101970, 80667, 56538, 100420)
order by
		rank

