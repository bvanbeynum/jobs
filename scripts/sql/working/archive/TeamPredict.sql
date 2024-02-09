
/*

select	*
from	TeamRank
where	TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
order by
		TeamName

*/

if object_id('tempdb..#team') is not null
	drop table #team

if object_id('tempdb..#opponent') is not null
	drop table #opponent

declare @OpponentTeam varchar(255)
set @OpponentTeam = 'South Pointe'

create table #Team (
	WrestlerID int
	, WeightClass varchar(255)
	, Wrestler varchar(255)
	, ELO decimal(9,5)
	, Events int
	, Wins int
	, Losses int
	, Division varchar(255)
	, EventName varchar(255)
	, EventDate date
	, WeightSort int
)

create table #Opponent (
	WrestlerID int
	, WeightClass varchar(255)
	, Wrestler varchar(255)
	, ELO decimal(9,5)
	, Events int
	, Wins int
	, Losses int
	, Division varchar(255)
	, EventName varchar(255)
	, EventDate date
	, WeightSort int
)

insert	#Opponent (
		WrestlerID
		, WeightClass
		, Wrestler
		, ELO
		, Events
		, Wins
		, Losses
		, Division
		, EventName
		, EventDate
		, WeightSort
		)
select	FloWrestler.ID
		, case when FloWrestler.LastName = 'Hays' then '106' else LastEvent.WeightClass end
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, ELO = ELORank.Ranking
		, Record.Events
		, Record.Wins
		, Record.Losses
		, LastEvent.Division
		, LastEvent.EventName
		, LastEvent.EventDate
		, WeightSort = row_number() over (
			partition by LastEvent.WeightClass
			order by
				case when LastEvent.Division in ('hs', 'high school', 'varsity') then 1
					when LastEvent.Division in ('jv', 'junior varsity', 'jr varsity') then 2
					else 3 end
				, ELORank.Ranking desc
				, Record.Wins - Record.Losses desc
			)
from	FloWrestler
left join
		ELORank
on		FloWrestler.ID = ELORank.FloWrestlerID
		and ELORank.ELOSummaryID = (select max(ELOSummaryID) from ELORank)
outer apply (
		select	top 1 EventName = FloMeet.MeetName
				, EventDate = cast(FloMeet.StartTime as date)
				, FloMatch.WeightClass
				, FloMatch.Division
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
				and isnumeric(FloMatch.WeightClass) = 1
				and FloMatch.WeightClass in ('106', '113', '120', '126', '132', '138', '145', '152', '160', '170', '182', '195', '220', '285')
		order by
				FloMeet.StartTime desc
		) LastEvent
outer apply (
		select	Events = count(distinct FloMeet.ID)
				, Wins = count(distinct case when FloWrestlerMatch.IsWinner = 1 then FloMatch.ID else null end)
				, Losses = count(distinct case when FloWrestlerMatch.IsWinner = 0 then FloMatch.ID else null end)
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		) Record
where	trim(FloWrestler.TeamName) like @OpponentTeam
		and LastEvent.EventDate > getdate() - 390
		and isnumeric(LastEvent.WeightClass) = 1


insert	#Team (
		WrestlerID
		, WeightClass
		, Wrestler
		, ELO
		, Events
		, Wins
		, Losses
		, Division
		, EventName
		, EventDate
		, WeightSort
		)
select	FloWrestler.ID
		, WeightClass = case 
			when FloWrestler.LastName = 'nally' then '113' 
			when FloWrestler.LastName = 'eubanks' then '138'
			when FloWrestler.LastName = 'murphy' then '106'
			when FloWrestler.LastName = 'greene' then '120'
			when FloWrestler.FirstName = 'gavin' then '145'
			when FloWrestler.FirstName = 'broden' then '160'
			when FloWrestler.LastName = 'kadish' then '170'
			when FloWrestler.ID = 56882 then '182'
			when FloWrestler.FirstName = 'sebastian' then '195'
			when FloWrestler.LastName = 'Richardson' then '220'
			when FloWrestler.LastName = 'Upchurch' then '285'
			else LastEvent.WeightClass end
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, ELO = ELORank.Ranking
		, Record.Events
		, Record.Wins
		, Record.Losses
		, LastEvent.Division
		, LastEvent.EventName
		, LastEvent.EventDate
		, WeightSort = row_number() over (
			partition by case 
				when FloWrestler.LastName = 'nally' then '113' 
				when FloWrestler.LastName = 'eubanks' then '138'
				when FloWrestler.LastName = 'murphy' then '106'
				when FloWrestler.LastName = 'greene' then '120'
				when FloWrestler.FirstName = 'gavin' then '145'
				when FloWrestler.FirstName = 'broden' then '160'
				when FloWrestler.LastName = 'kadish' then '170'
				when FloWrestler.ID = 56882 then '182'
				when FloWrestler.FirstName = 'sebastian' then '195'
				when FloWrestler.LastName = 'Richardson' then '220'
				when FloWrestler.LastName = 'Upchurch' then '285'
				else LastEvent.WeightClass end
			order by
				case when LastEvent.Division in ('hs', 'high school', 'varsity', 'high') or FloWrestler.ID = 8052 then 1
					when LastEvent.Division in ('jv', 'junior varsity', 'jr varsity') then 2
					else 3 end
				, case when FloWrestler.ID = 28386 then 1 else 2 end -- Put Sebastian over Lloyd
				, ELORank.Ranking desc
				, Record.Wins - Record.Losses desc
			)
from	FloWrestler
left join
		ELORank
on		FloWrestler.ID = ELORank.FloWrestlerID
		and ELORank.ELOSummaryID = (select max(ELOSummaryID) from ELORank)
outer apply (
		select	top 1 EventName = FloMeet.MeetName
				, EventDate = cast(FloMeet.StartTime as date)
				, FloMatch.WeightClass
				, FloMatch.Division
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
				and isnumeric(FloMatch.WeightClass) = 1
		order by
				FloMeet.StartTime desc
		) LastEvent
outer apply (
		select	Events = count(distinct FloMeet.ID)
				, Wins = count(distinct case when FloWrestlerMatch.IsWinner = 1 then FloMatch.ID else null end)
				, Losses = count(distinct case when FloWrestlerMatch.IsWinner = 0 then FloMatch.ID else null end)
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		) Record
where	FloWrestler.TeamName = 'fort mill'
		and (LastEvent.EventDate > getdate() - 390 or FloWrestler.ID in (25272, 28386))
		and isnumeric(LastEvent.WeightClass) = 1
		and FloWrestler.LastName not in ('kitchton', 'brock', 'zgrabik', 'smith', 'miller', 'debbout')

select	Opponent.WeightClass
		, Opponent.Wrestler
		, OpponentPrediciton = cast((1.0 / (1.0 + power(10.0, (Team.ELO - Opponent.ELO) / 400.0))) * 100 as int)
		, FMPrediciton = cast((1.0 / (1.0 + power(10.0, (Opponent.ELO - Team.ELO) / 400.0))) * 100 as int)
		, team.Wrestler
from	#Opponent Opponent
left join
		#team Team
on		Opponent.WeightClass = team.WeightClass
		and team.WeightSort < 2
		and (Team.WeightSort = 1 or Team.ELO is not null)
where	isnumeric(Opponent.WeightClass) = 1
		and Opponent.WeightSort < 2
		and (Opponent.WeightSort = 1 or Opponent.ELO is not null)
order by
		Opponent.WeightClass
		, Opponent.WeightSort
		, Team.WeightSort

-- select * from #team order by WeightClass, WeightSort
