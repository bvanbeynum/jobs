
if object_id('tempdb..#wrestlers') is not null
	drop table #wrestlers

if object_id('tempdb..#WrestlerMatches') is not null
	drop table #WrestlerMatches

if object_id('tempdb..#WrestlerLineage') is not null
	drop table #WrestlerLineage

select	WrestlerID = row_number() over (order by AllWrestlers.team, AllWrestlers.WrestlerName)
		, AllWrestlers.WrestlerName
		, AllWrestlers.team
		, FloWrestlerID = min(WrestlerFlo.FloWrestlerID)
		, TrackWrestlerID = min(WrestlerTrack.TrackWrestlerID)
into	#Wrestlers
from	(
		select	distinct WrestlerName = FloWrestlerMatch.FirstName + ' ' + FloWrestlerMatch.LastName
				, FloWrestlerMatch.Team
		from	TeamRank
		join	FloWrestlerMatch
		on		TeamRank.TeamName = FloWrestlerMatch.Team
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloMeet.StartTime > getdate() - 720
		union
		select	distinct TrackWrestlerMatch.WrestlerName
				, TrackWrestlerMatch.Team
		from	TeamRank
		join	TrackWrestlerMatch
		on		TeamRank.TeamName = TrackWrestlerMatch.Team
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TrackEvent.EventDate > getdate() - 720
				and len(TrackWrestlerMatch.WrestlerName) > 0
				and TrackWrestlerMatch.Team is not null
		) AllWrestlers
outer apply (
		select	distinct FloWrestlerMatch.FloWrestlerID
		from	FloWrestlerMatch
		where	AllWrestlers.WrestlerName = FloWrestlerMatch.FirstName + ' ' + FloWrestlerMatch.LastName
				and AllWrestlers.Team = FloWrestlerMatch.Team
		) WrestlerFlo
outer apply (
		select	distinct TrackWrestlerMatch.TrackWrestlerID
		from	TrackWrestlerMatch
		where	AllWrestlers.WrestlerName = TrackWrestlerMatch.WrestlerName
				and AllWrestlers.Team = TrackWrestlerMatch.Team
		) WrestlerTrack
group by
		AllWrestlers.WrestlerName
		, AllWrestlers.team


-- All Matches

select	EventSystem
		, EventDate
		, IsWinner
		, MatchID
		, WrestlerID
		, WrestlerName
		, Team
into	#WrestlerMatches
from	(
		select	EventSystem = cast('Flo' as varchar(25))
				, EventDate = cast(FloMeet.StartTime as date)
				, FloWrestlerMatch.IsWinner
				, MatchID = FloWrestlerMatch.FloMatchID
				, Wrestlers.WrestlerID
				, Wrestlers.WrestlerName
				, Wrestlers.Team
		from	#Wrestlers Wrestlers
		join	FloWrestlerMatch
		on		Wrestlers.FloWrestlerID = FloWrestlerMatch.FloWrestlerID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloMeet.StartTime > getdate() - 720
		union all
		select	EventSystem = cast('Track' as varchar(25))
				, EventDate = cast(TrackEvent.EventDate as date)
				, TrackWrestlerMatch.IsWinner
				, MatchID = TrackWrestlerMatch.TrackMatchID
				, Wrestlers.WrestlerID
				, Wrestlers.WrestlerName
				, Wrestlers.Team
		from	#Wrestlers Wrestlers
		join	TrackWrestlerMatch
		on		Wrestlers.TrackWrestlerID = TrackWrestlerMatch.TrackWrestlerID
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TrackEvent.EventDate > getdate() - 720
				and len(TrackWrestlerMatch.WrestlerName) > 0
				and TrackWrestlerMatch.Team is not null
		) AllMatches

-- Initial load

select	InitialWrestlerID
		, EventDate
		, IsWinner
		, Tier = 1
		, Wrestler1ID
		, Wrestler1Name
		, Wrestler1Team
		, Wrestler2ID
		, Wrestler2Name
		, Wrestler2Team
into	#WrestlerLineage
from	(
		select	InitialWrestlerID = Wrestlers.WrestlerID
				, WrestlerMatches.EventSystem
				, WrestlerMatches.EventDate
				, WrestlerMatches.IsWinner
				, WrestlerMatches.MatchID
				, Wrestler1ID = WrestlerMatches.WrestlerID
				, Wrestler1Name = WrestlerMatches.WrestlerName
				, Wrestler1Team = WrestlerMatches.Team
				, Wrestler2ID = OtherWrestler.WrestlerID
				, Wrestler2Name = OtherWrestler.WrestlerName
				, Wrestler2Team = OtherWrestler.Team
				, MostRecent = row_number() over (partition by Wrestlers.WrestlerID, WrestlerMatches.WrestlerID, OtherWrestler.WrestlerID order by WrestlerMatches.EventDate desc, WrestlerMatches.MatchID desc)
		from	#Wrestlers Wrestlers
		join	#WrestlerMatches WrestlerMatches
		on		Wrestlers.WrestlerID = WrestlerMatches.WrestlerID
		join	#WrestlerMatches OtherWrestler
		on		WrestlerMatches.MatchID = OtherWrestler.MatchID
				and WrestlerMatches.EventSystem = OtherWrestler.EventSystem
				and WrestlerMatches.WrestlerID <> OtherWrestler.WrestlerID
		) Matches
where	MostRecent = 1

-- Loop

declare @Iteration int;
set @Iteration = 1;

while @Iteration < 6
begin

insert	#WrestlerLineage (
		InitialWrestlerID
		, EventDate
		, IsWinner
		, Tier
		, Wrestler1ID
		, Wrestler1Name
		, Wrestler1Team
		, Wrestler2ID
		, Wrestler2Name
		, Wrestler2Team
		)
select	InitialWrestlerID
		, EventDate
		, IsWinner
		, Tier
		, Wrestler1ID
		, Wrestler1Name
		, Wrestler1Team
		, Wrestler2ID
		, Wrestler2Name
		, Wrestler2Team
from	(
		select	StartingMatch.InitialWrestlerID
				, WrestlerMatches.EventDate
				, WrestlerMatches.IsWinner
				, Tier = StartingMatch.Tier + 1
				, Wrestler1ID = WrestlerMatches.WrestlerID
				, Wrestler1Name = WrestlerMatches.WrestlerName
				, Wrestler1Team = WrestlerMatches.Team
				, Wrestler2ID = OtherWrestler.WrestlerID
				, Wrestler2Name = OtherWrestler.WrestlerName
				, Wrestler2Team = OtherWrestler.Team
				, MostRecent = row_number() over (partition by StartingMatch.InitialWrestlerID, WrestlerMatches.WrestlerID, OtherWrestler.WrestlerID order by WrestlerMatches.EventDate desc, WrestlerMatches.MatchID desc)
		from	#WrestlerLineage StartingMatch
		join	#WrestlerMatches WrestlerMatches
		on		StartingMatch.Wrestler2ID = WrestlerMatches.WrestlerID
				and StartingMatch.IsWinner = WrestlerMatches.IsWinner -- Only get matches that match the win type of the parent
		join	#WrestlerMatches OtherWrestler
		on		WrestlerMatches.MatchID = OtherWrestler.MatchID
				and WrestlerMatches.EventSystem = OtherWrestler.EventSystem
				and WrestlerMatches.WrestlerID <> OtherWrestler.WrestlerID
		left join
				#WrestlerLineage FilterOpponent
		on		StartingMatch.InitialWrestlerID = FilterOpponent.InitialWrestlerID
				and OtherWrestler.WrestlerID = FilterOpponent.Wrestler1ID
		outer apply (
				select	Matches = count(distinct FMTeam.WrestlerID)
				from	#Wrestlers FMTeam
				where	WrestlerMatches.WrestlerID = FMTeam.WrestlerID
						and FMTeam.Team = 'fort mill'
				) IsFortMill
		where	FilterOpponent.Wrestler1ID is null
				and IsFortMill.Matches = 0
				and StartingMatch.Tier = @Iteration
		) Matches
where	MostRecent = 1

set @Iteration = @Iteration + 1

end

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

if object_id('tempdb..#ModifiedLineage') is not null
	drop table #ModifiedLineage

select	distinct WrestlerTemp.WrestlerID
		, WrestlerTemp.FloWrestlerID
		, WrestlerTemp.TrackWrestlerID
into	#ModifiedLineage
from	#Wrestlers WrestlerTemp
join	#WrestlerLineage LineageTemp
on		WrestlerTemp.WrestlerID = LineageTemp.InitialWrestlerID
left join
		WrestlerLineage
on		coalesce(WrestlerTemp.FloWrestlerID, '') = coalesce(WrestlerLineage.FloWrestlerID, '')
		and coalesce(WrestlerTemp.TrackWrestlerID, '') = coalesce(WrestlerLineage.TrackWrestlerID, '')
		and LineageTemp.Wrestler1ID = WrestlerLineage.Wrestler1ID
		and LineageTemp.Wrestler2ID = WrestlerLineage.Wrestler2ID
where	WrestlerLineage.ID is null

delete
from	WrestlerLineage
from	WrestlerLineage
join	#ModifiedLineage ModifiedLineage
on		coalesce(WrestlerLineage.FloWrestlerID, '') = coalesce(ModifiedLineage.FloWrestlerID, '')
		and coalesce(WrestlerLineage.TrackWrestlerID, '') = coalesce(ModifiedLineage.TrackWrestlerID, '')

insert	WrestlerLineage (
		WrestlerID
		, FloWrestlerID
		, TrackWrestlerID
		, Wrestler1ID
		, Wrestler1Flo
		, Wrestler1Track
		, Wrestler1Name
		, Wrestler1Team
		, Wrestler2ID
		, Wrestler2Flo
		, Wrestler2Track
		, Wrestler2Name
		, Wrestler2Team
		, Tier
		, EventDate
		, IsWinner
		)
select	WrestlerTemp.WrestlerID
		, WrestlerTemp.FloWrestlerID
		, WrestlerTemp.TrackWrestlerID
		, LineageTemp.Wrestler1ID
		, Wrestler1Flo = Wrestler1.FloWrestlerID
		, Wrestler1Track = Wrestler1.TrackWrestlerID
		, LineageTemp.Wrestler1Name
		, LineageTemp.Wrestler1Team
		, LineageTemp.Wrestler2ID
		, Wrestler2Flo = Wrestler2.FloWrestlerID
		, Wrestler2Track = Wrestler2.TrackWrestlerID
		, LineageTemp.Wrestler2Name
		, LineageTemp.Wrestler2Team
		, LineageTemp.Tier
		, LineageTemp.EventDate
		, LineageTemp.IsWinner
from	#ModifiedLineage WrestlerTemp
join	#WrestlerLineage LineageTemp
on		WrestlerTemp.WrestlerID = LineageTemp.InitialWrestlerID
outer apply (
		select	Wrestlers.FloWrestlerID
				, wrestlers.TrackWrestlerID
		from	#Wrestlers Wrestlers
		where	LineageTemp.Wrestler1ID = Wrestlers.WrestlerID
		) Wrestler1
outer apply (
		select	Wrestlers.FloWrestlerID
				, wrestlers.TrackWrestlerID
		from	#Wrestlers Wrestlers
		where	LineageTemp.Wrestler2ID = Wrestlers.WrestlerID
		) Wrestler2
where	WrestlerTemp.WrestlerID = 3418

select * from #WrestlerLineage where InitialWrestlerID = 3418 and iswinner = 0

select * from #ModifiedLineage where FloWrestlerID = 99702



;with lineagecte as (
select	WrestlerLineage.InitialWrestlerID
		, WrestlerLineage.Tier
		, WrestlerLineage.Wrestler2ID
		, WrestlerLineage.IsWinner
		, WrestlerLineage.Wrestler2Team
		, Lineage = cast(
			WrestlerLineage.Wrestler1Name +
			case when WrestlerLineage.IsWinner = 1 then ' beat ' else ' lost to ' end + 
			WrestlerLineage.Wrestler2Name
		as varchar(max))
from	#WrestlerLineage WrestlerLineage
where	WrestlerLineage.Tier = 1
		and WrestlerLineage.InitialWrestlerID = 3418
		and WrestlerLineage.IsWinner = 0
union all
select	lineagecte.InitialWrestlerID
		, opponents.Tier
		, opponents.Wrestler2ID
		, opponents.IsWinner
		, opponents.Wrestler2Team
		, Lineage = lineagecte.Lineage +
			' \ ' +
			opponents.Wrestler1Name +
			case when opponents.IsWinner = 1 then ' beat ' else 'lost to ' end + 
			opponents.Wrestler2Name
from	lineagecte
join	#WrestlerLineage opponents
on		lineagecte.Wrestler2ID = opponents.Wrestler1ID
		and lineagecte.IsWinner = opponents.IsWinner
		and lineagecte.Tier = opponents.Tier - 1
		-- and lineagecte.InitialWrestlerID = opponents.InitialWrestlerID
)
select	Lineage
from	lineagecte
where	lineagecte.Wrestler2Team = 'fort mill'
order by
		Lineage


/*

commit;

rollback;

*/
