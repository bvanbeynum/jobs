
if object_id('tempdb..#wrestlers') is not null
	drop table #wrestlers


if object_id('tempdb..#AllMatches') is not null
	drop table #AllMatches

if object_id('tempdb..#WrestlerMatches') is not null
	drop table #WrestlerMatches

if object_id('tempdb..#MatchWrestlers') is not null
	drop table #MatchWrestlers

if object_id('tempdb..#WrestlerLineage') is not null
	drop table #WrestlerLineage

select	WrestlerID = row_number() over (order by max(team), max(WrestlerName))
		, FloWrestlerID
		, TrackWrestlerID = max(TrackWrestlerID)
		, WrestlerName = max(WrestlerName)
		, Team = max(team)
into	#Wrestlers
from	(
		select	FloWrestlerID = max(WrestlerFlo.FloWrestlerID)
				, TrackWrestlerID = max(WrestlerTrack.TrackWrestlerID)
				, AllWrestlers.WrestlerName
				, AllWrestlers.team
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
		) SystemGroup
group by
		FloWrestlerID

-- All Matches

select	MatchID
		, EventDate
		, Sort
		, Wrestler1
		, Wrestler2
		, EventSystem
into	#AllMatches
from	(
		select	MatchID = FloWrestlerMatch.FloMatchID
				, EventDate = cast(FloMeet.StartTime as date)
				, FloMatch.Sort
				, Wrestler1 = min(Wrestlers.WrestlerID)
				, Wrestler2 = max(Wrestlers.WrestlerID)
				, EventSystem = 'flo'
		from	#Wrestlers Wrestlers
		join	FloWrestlerMatch WrestlerMatch
		on		Wrestlers.FloWrestlerID = WrestlerMatch.FloWrestlerID
		join	FloWrestlerMatch
		on		WrestlerMatch.FloMatchID = FloWrestlerMatch.FloMatchID
				and WrestlerMatch.FloWrestlerID <> FloWrestlerMatch.FloWrestlerID
		join	FloMatch
		on		FloWrestlerMatch.FloMatchID = FloMatch.ID
		join	FloMeet
		on		FloMatch.FloMeetID = FloMeet.ID
		where	FloMeet.StartTime > getdate() - 720
		group by
				FloWrestlerMatch.FloMatchID
				, cast(FloMeet.StartTime as date)
				, FloMatch.Sort
		having	count(distinct Wrestlers.WrestlerID) > 1
		union all
		select	MatchID = TrackWrestlerMatch.TrackMatchID
				, TrackEvent.EventDate
				, TrackMatch.Sort
				, Wrestler1 = min(Wrestlers.WrestlerID)
				, Wrestler2 = max(Wrestlers.WrestlerID)
				, EventSystem = 'track'
		from	#Wrestlers Wrestlers
		join	TrackWrestlerMatch WrestlerMatch
		on		Wrestlers.TrackWrestlerID = WrestlerMatch.TrackWrestlerID
		join	TrackWrestlerMatch
		on		WrestlerMatch.TrackMatchID = TrackWrestlerMatch.TrackMatchID
		join	TrackMatch
		on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
		join	TrackEvent
		on		TrackMatch.TrackEventID = TrackEvent.ID
		where	TrackEvent.EventDate > getdate() - 720
		group by
				TrackWrestlerMatch.TrackMatchID
				, TrackEvent.EventDate
				, TrackMatch.Sort
		having	count(distinct Wrestlers.WrestlerID) > 1
		) Matches;

select	MatchID = row_number() over (order by EventDate, Wrestler1, Wrestler2)
		, Wrestler1
		, Wrestler2
		, Wrestler1Win
		, Wrestler2Win
		, EventDate
into	#WrestlerMatches
from	(
		select	Wrestler1
				, Wrestler2
				, Wrestler1Win = case when EventSystem = 'flo' then FloWinner1.IsWinner else TrackWinner1.IsWinner end
				, Wrestler2Win = case when EventSystem = 'flo' then FloWinner2.IsWinner else TrackWinner2.IsWinner end
				, EventDate
				, MatchFilter = row_number() over (partition by Wrestler1, wrestler2 order by EventDate desc, Sort desc)
		from	#AllMatches Matches
		outer apply (
				select	FloWrestlerMatch.IsWinner
				from	FloWrestlerMatch
				join	#Wrestlers wrestlers
				on		FloWrestlerMatch.FloWrestlerID = wrestlers.FloWrestlerID
				where	Matches.MatchID = FloWrestlerMatch.FloMatchID
						and Matches.EventSystem = 'flo'
						and Matches.Wrestler1 = wrestlers.WrestlerID
				) FloWinner1
		outer apply (
				select	FloWrestlerMatch.IsWinner
				from	FloWrestlerMatch
				join	#Wrestlers wrestlers
				on		FloWrestlerMatch.FloWrestlerID = wrestlers.FloWrestlerID
				where	Matches.MatchID = FloWrestlerMatch.FloMatchID
						and Matches.EventSystem = 'flo'
						and Matches.Wrestler2 = wrestlers.WrestlerID
				) FloWinner2
		outer apply (
				select	TrackWrestlerMatch.IsWinner
				from	TrackWrestlerMatch
				join	#Wrestlers wrestlers
				on		TrackWrestlerMatch.TrackWrestlerID = wrestlers.TrackWrestlerID
				where	Matches.MatchID = TrackWrestlerMatch.TrackMatchID
						and Matches.EventSystem = 'track'
						and Matches.Wrestler1 = wrestlers.WrestlerID
				) TrackWinner1
		outer apply (
				select	TrackWrestlerMatch.IsWinner
				from	TrackWrestlerMatch
				join	#Wrestlers wrestlers
				on		TrackWrestlerMatch.TrackWrestlerID = wrestlers.TrackWrestlerID
				where	Matches.MatchID = TrackWrestlerMatch.TrackMatchID
						and Matches.EventSystem = 'track'
						and Matches.Wrestler2 = wrestlers.WrestlerID
				) TrackWinner2
		) LastMatch
where	LastMatch.MatchFilter = 1

-- Split out wrestlers for matches

select	MatchWrestlerSplit.MatchID
		, MatchWrestlerSplit.WrestlerID
		, MatchWrestlerSplit.IsWinner
		, MatchWrestlerSplit.EventDate
		, Wrestlers.WrestlerName
		, Wrestlers.Team
		, wrestlers.FloWrestlerID
into	#MatchWrestlers
from	(
		select	MatchID
				, WrestlerID = Wrestler1
				, IsWinner = Wrestler1Win
				, EventDate
		from	#WrestlerMatches
		union all
		select	MatchID
				, WrestlerID = Wrestler2
				, IsWinner = Wrestler2Win
				, EventDate
		from	#WrestlerMatches
		) MatchWrestlerSplit
join	#Wrestlers Wrestlers
on		MatchWrestlerSplit.WrestlerID = Wrestlers.WrestlerID;

create index idx_MatchWrestlers_WrestlerID on #MatchWrestlers (WrestlerID);
create index idx_MatchWrestlers_MatchID on #MatchWrestlers (MatchID);

-- Initial load

truncate table WrestlerLineage;

insert	WrestlerLineage (
		InitialWrestlerID
		, InitialFloID
		, Tier
		, IsWinner
		, Wrestler2FloID
		, Wrestler2Team
		, Packet
		)
select	InitialWrestlerID = WrestlerMatches.WrestlerID
		, InitialFloID = WrestlerMatches.FloWrestlerID
		, Tier = 1
		, WrestlerMatches.IsWinner
		, Wrestler2FloID = OtherWrestler.FloWrestlerID
		, Wrestler2Team = OtherWrestler.Team
		, Packet = cast(
			'{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.Team + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.Team + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": 1,' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
			as varchar(max))
from	#MatchWrestlers WrestlerMatches
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.MatchID = OtherWrestler.MatchID
		and WrestlerMatches.WrestlerID <> OtherWrestler.WrestlerID


-- Loop

declare @Iteration int;
set @Iteration = 1;

while @Iteration < 6
begin

insert	WrestlerLineage (
		InitialWrestlerID
		, InitialFloID
		, Tier
		, IsWinner
		, Wrestler2FloID
		, Wrestler2Team
		, Packet
		)
select	WrestlerLineage.InitialWrestlerID
		, WrestlerLineage.InitialFloID
		, Tier = WrestlerLineage.Tier + 1
		, WrestlerMatches.IsWinner
		, Wrestler2ID = OtherWrestler.FloWrestlerID
		, Wrestler2Team = OtherWrestler.Team
		, Packet = WrestlerLineage.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.Team + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.Team + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(WrestlerLineage.Tier + 1 as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
from	WrestlerLineage
join	#MatchWrestlers WrestlerMatches
on		WrestlerLineage.Wrestler2FloID = WrestlerMatches.FloWrestlerID
		and WrestlerLineage.IsWinner = WrestlerMatches.IsWinner
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.MatchID = OtherWrestler.MatchID
		and WrestlerMatches.WrestlerID <> OtherWrestler.WrestlerID
where	WrestlerLineage.Wrestler2Team <> 'fort mill'

set @Iteration = @Iteration + 1

raiserror('Iteration %i', 10, 1, @Iteration) with nowait;

end

select	InitialFloID
		, Tier
		, Wrestler2FloID
		, FirstRecord = min(ID)
into	#DupRecords
from	WrestlerLineage
group by
		InitialFloID
		, Tier
		, Wrestler2FloID
having	count(0) > 1

select	WrestlerLineage.InitialFloID
		, WrestlerLineage.Wrestler2FloID
		, FirstTier = min(Tier)
		, LastTier = max(Tier)
into	#LineageTier
from	WrestlerLineage
where	WrestlerLineage.Wrestler2Team = 'fort mill'
group by
		WrestlerLineage.InitialFloID
		, WrestlerLineage.Wrestler2FloID

begin transaction

delete
from	WrestlerLineage
from	WrestlerLineage
join	#LineageTier LineageTier
on		WrestlerLineage.InitialFloID = LineageTier.InitialFloID
		and WrestlerLineage.Wrestler2FloID = LineageTier.Wrestler2FloID
		and WrestlerLineage.Tier > LineageTier.FirstTier

commit

select	WrestlerLineage.InitialWrestlerID
		, WrestlerLineage.InitialFloID
		, Tier = WrestlerLineage.Tier + 1
		, WrestlerMatches.IsWinner
		, Wrestler2ID = OtherWrestler.FloWrestlerID
		, Wrestler2Team = OtherWrestler.Team
		, Packet = WrestlerLineage.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.Team + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.Team + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(WrestlerLineage.Tier + 1 as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
from	WrestlerLineage
join	#MatchWrestlers WrestlerMatches
on		WrestlerLineage.Wrestler2FloID = WrestlerMatches.FloWrestlerID
		and WrestlerLineage.IsWinner = WrestlerMatches.IsWinner
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.MatchID = OtherWrestler.MatchID
		and WrestlerMatches.WrestlerID <> OtherWrestler.WrestlerID
where	WrestlerLineage.Wrestler2Team <> 'fort mill'

select	max(Tier)
from	WrestlerLineage
where	WrestlerLineage.wrestler2Team <> 'fort mill'
