return;

if object_id('tempdb..#dedup') is not null
	drop table #dedup

if object_id('tempdb..#fixedids') is not null
	drop table #fixedids

select	NewID = FloWrestler.ID
		, FixID = Duplicate.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, Duplicate.TeamName
		, Duplicate.[State]
-- into	#fixedids
from	FloWrestler
join	FloWrestler Duplicate
on		FloWrestler.FirstName = Duplicate.FirstName
		and FloWrestler.LastName = Duplicate.LastName
		and FloWrestler.TeamName <> Duplicate.TeamName
where	FloWrestler.ID = 28377
order by
		Duplicate.ID

-- select	*
-- into	#fixedids
-- from	(
-- 		select	NewID = min(FloWrestler.id) over ()
-- 				, FixID = FloWrestler.id
-- 				, FirstName
-- 				, LastName
-- 				, TeamName
-- 		from	FloWrestler
-- 		where	LastName like 'lutz'
-- 		) Dups
-- where	newid <> FixID

select * from #fixedids

update	FloWrestlerMatch
set		FloWrestlerID = fix.NewID
		, ModifiedDate = getdate()
from	FloWrestlerMatch
join	#fixedids fix
on		FloWrestlerMatch.FloWrestlerID = fix.FixID

delete
from	FloWrestler
from	FloWrestler
left join
		FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
where	FloWrestlerMatch.ID is null

select	min(FloWrestler.ID) WrestlerID
		, FirstName = replace(FirstName, ' ', '')
		, LastName = replace(LastName, ' ', '')
		, TeamName
into	#dedup
from	FloWrestler
group by
		replace(FirstName, ' ', '')
		, replace(LastName, ' ', '')
		, TeamName
having	count(0) > 1

-- select * from #dedup

select	dedup.WrestlerID NewID
		, FloWrestler.ID FixID
into	#fixedids
from	#dedup dedup
join	FloWrestler
on 		replace(FloWrestler.FirstName, ' ', '') = dedup.FirstName
		and replace(FloWrestler.LastName, ' ', '') = dedup.LastName
		and FloWrestler.TeamName = dedup.TeamName
		and FloWrestler.id <> dedup.WrestlerID

-- select * from #fixedids

-- select	8145 NewID
-- 		, FloWrestler.ID FixID
-- into	#fixedids
-- from	FloWrestler
-- where	FloWrestler.ID in (93589, 94070)

/*

drop table #teamname;
drop table #namegroup;
drop table #teamword;
drop table #mergeoptions;
drop table #teamcleanup;

*/

select	CleanName = replace(replace(replace(replace(replace(teamname, '-', ' '), '/', ' '), '.', ''), ',', ' '), '  ', ' ')
		, OriginalName = FloWrestler.TeamName
		, Meets = count(distinct FloMatch.FloMeetID)
into	#teamname
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
group by
		FloWrestler.TeamName

select	ID = row_number() over (order by CleanName)
		, CleanName
		, Meets = sum(Meets)
into	#namegroup
from	#teamname
group by
		CleanName

select	namegroup.ID
		, namegroup.CleanName
		, namegroup.Meets
		, Ordinal = row_number() over (partition by namegroup.id order by (select 0))
		, Word = Split.[value]
into	#teamword
from	#namegroup namegroup
cross apply
		string_split(namegroup.CleanName, ' ') Split
order by
		namegroup.ID

create index idx_tempteamword on #teamword (id)

select	*
into	#mergeoptions
from	(
		select	MatchWord = option1.Word
				, rank = rank() over (partition by option1.Word order by option1.Meets desc, len(option1.CleanName))
				, ID1 = option1.ID
				, Name1 = option1.CleanName
				, Meets1 = option1.Meets
				, ID2 = option2.ID
				, Name2 = option2.CleanName
				, Meets2 = option2.Meets
		from	#teamword option1
		join	#teamword option2
		on		option1.Word = option2.Word
				and option1.Ordinal = 1
				and option2.Ordinal = 1
				and option1.ID <> option2.ID
				and len(option1.Word) > 2
		group by
				option1.Word
				, option1.ID
				, option1.CleanName
				, option1.Meets
				, option2.ID
				, option2.CleanName
				, option2.Meets
		) mergeoptions
where	rank = 1

select	teamname.OriginalName
		, ChangeName = options.Name1
into	#teamcleanup
from	#mergeoptions options
join	#namegroup namegroup
on		options.ID2 = namegroup.ID
join	#teamname teamname
on		namegroup.CleanName = teamname.CleanName
cross apply (
		select	replace(FloWrestler.FirstName, ' ', '') + replace(FloWrestler.LastName, ' ', '') WrestlerName
		from	#namegroup
		join	#teamname
		on		#namegroup.CleanName = #teamname.CleanName
		join	FloWrestler
		on		#teamname.OriginalName = FloWrestler.TeamName
		where	options.ID1 = #namegroup.ID
		) Wrestler1
cross apply (
		select	replace(FloWrestler.FirstName, ' ', '') + replace(FloWrestler.LastName, ' ', '') WrestlerName
		from	#namegroup
		join	#teamname
		on		#namegroup.CleanName = #teamname.CleanName
		join	FloWrestler
		on		#teamname.OriginalName = FloWrestler.TeamName
		where	options.ID2 = #namegroup.ID
		) Wrestler2
where	Wrestler1.WrestlerName = Wrestler2.WrestlerName
group by
		teamname.OriginalName
		, options.Name1

select * from #teamcleanup

update	FloWrestler
set		TeamName = cleanup.ChangeName
from	FloWrestler
join	#teamcleanup cleanup
on		FloWrestler.TeamName = cleanup.OriginalName


select	NewID = TrackWrestler.ID
		, FixID = Duplicate.ID
		, TrackWrestler.WrestlerName
		, Duplicate.TeamName
into	#fixedids
from	TrackWrestler
join	TrackWrestler Duplicate
on		TrackWrestler.WrestlerName = Duplicate.WrestlerName
		and TrackWrestler.TeamName <> Duplicate.TeamName
where	TrackWrestler.ID = 3978
order by
		Duplicate.ID

select * from FloWrestler where FirstName + ' ' + LastName like 'p% white%'
select * from TrackWrestler where WrestlerName like 'p% whit%'

select	*
into	#fixedids
from	(
		select	NewID = min(id) over ()
				, FixID = id
		from	TrackWrestler
		where	WrestlerName like 'Cj Williams'
		) Dups
where	newid <> FixID

select	min(TrackWrestler.ID) WrestlerID
		, WrestlerName = replace(WrestlerName, ' ', '')
		, TeamName
		, DupCount = count(0)
into	#dedup
from	TrackWrestler
group by
		replace(WrestlerName, ' ', '')
		, TeamName
having	count(0) > 1

-- select * from #dedup

select	dedup.WrestlerID NewID
		, TrackWrestler.ID FixID
into	#fixedids
from	#dedup dedup
join	TrackWrestler
on 		replace(TrackWrestler.WrestlerName, ' ', '') = dedup.wrestlerName
		and TrackWrestler.TeamName = dedup.TeamName
		and TrackWrestler.id <> dedup.WrestlerID

-- select * from #fixedids

update	TrackWrestlerMatch
set		TrackWrestlerID = fix.NewID
		, ModifiedDate = getdate()
from	TrackWrestlerMatch
join	#fixedids fix
on		TrackWrestlerMatch.TrackWrestlerID = fix.FixID

delete
from	TrackWrestler
from	TrackWrestler
left join
		TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
where	TrackWrestlerMatch.ID is null

update	TrackWrestler
set		TeamName = 'Stratford'
where	TeamName = 'Stratford Knights'

update	TrackWrestler
set		WrestlerName = 'Zachary Gomer-Chrobocinski'
where	id in (6459, 2712, 15758)

update	FloWrestler
set		FirstName = 'Jantzen'
		, LastName = 'Huneycutt'
where	FirstName + ' ' + LastName = 'Jantzen Honeycutt'

update	FloWrestler
set		TeamName = 'Clover'
where	TeamName = 'Clover B'
