
select * from ELOSummary;

select	top 1000 ELORank.ID
		, WrestlerRank = rank() over (order by ELORank.ranking desc)
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, FloWrestler.TeamName
		, LastWeight = LastMatch.WeightClass
		, LastEvent = LastMatch.MeetName
		, LastDate = LastMatch.MeetDate
from	ELORank
join	FloWrestler
on		ELORank.FloWrestlerID = FloWrestler.ID
-- join	TeamRank
-- on		FloWrestler.TeamName = TeamRank.TeamName
-- 		and TeamRank.SourceDate = (select max(SourceDate) from TeamRank)
outer apply (
		select	top 1 FloMatch.WeightClass
				, FloMeet.MeetName
				, MeetDate = cast(FloMeet.StartTime as date)
		from	FloWrestlerMatch
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloWrestlerMatch.FloWrestlerID = ELORank.FloWrestlerID
				and FloMeet.LocationState = 'sc'
				and FloMeet.StartTime > getdate() - 390
		group by
				FloMatch.WeightClass
				, FloMeet.MeetName
				, cast(FloMeet.StartTime as date)
		order by
				MeetDate desc
		) LastMatch
where	ELOSummaryID = 32
		and LastMatch.WeightClass = '106'
order by
		WrestlerRank


select	EventDate = cast(FloMeet.StartTime as date)
		, FloMeet.MeetName
		, Wrestler = FloWrestler.FirstName + ' ' + FloWrestler.LastName
		, ELOMatch.IsWinner
		, ELOMatch.Prediction
		, ELOMatch.InitialELO
		, Change = ELOMatch.RankUpdate
		, Vs = OtherWrestler.FirstName + ' ' + OtherWrestler.LastName
		, VsPrediction = AllMatch.Prediction
		, VsELO = AllMatch.InitialELO
		, VsChange = AllMatch.RankUpdate
		, VsELOID = OtherRank.ID
from	ELOMatch
join	ELORank
on		ELOMatch.ELORankID = ELORank.ID
		and ELORank.ELOSummaryID = 35
join	FloWrestler
on		ELORank.FloWrestlerID = FloWrestler.ID
join	ELOMatch AllMatch
on		ELOMatch.FloMatchID = AllMatch.FloMatchID
		and ELOMatch.ELORankID <> AllMatch.ELORankID
join	ELORank OtherRank
on		AllMatch.ELORankID = OtherRank.ID
		and OtherRank.ELOSummaryID = 35
join	FloWrestler OtherWrestler
on		OtherRank.FloWrestlerID = OtherWrestler.ID
join	FloMatch
on		ELOMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	ELOMatch.ELORankID = 784558
-- where	ELOMatch.FloMatchID in (70739, 70749, 70751, 70753, 50965, 50972, 50974, 50975)
order by
		AllMatch.Sort
