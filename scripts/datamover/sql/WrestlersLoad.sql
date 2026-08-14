set nocount on;

declare @TimespanDays int;
declare @EventDays int;
declare @Offset int;
declare @BatchSize int;

set @TimespanDays = ?;
set @EventDays = ?;
set @Offset = ?;
set @BatchSize = ?;

if object_id('tempdb..#PagedWrestler') is not null
	drop table #PagedWrestler

if object_id('tempdb..#WrestlerData') is not null
	drop table #WrestlerData

select	EventWrestlerMatch.EventWrestlerID
		, LastModified = max(EventWrestlerMatch.ModifiedDate)
into	#PagedWrestler
from	EventWrestlerMatch
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
where	EventWrestlerMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
		and Event.EventDate >= dateadd(day, @EventDays, getdate())
group by
		EventWrestlerMatch.EventWrestlerID
order by
		max(EventWrestlerMatch.ModifiedDate) desc
		, EventWrestlerMatch.EventWrestlerID
offset @Offset rows fetch next @BatchSize rows only;

select	EventWrestlerMatch.EventWrestlerID
		, Event.EventName
		, Event.EventDate
		, Event.EventState
		, WrestlerName = max(EventWrestlerMatch.WrestlerName)
		, TeamName = max(coalesce(School.SchoolName, EventWrestlerMatch.TeamName))
		, IsSchoolTeam = max(case when School.ID is not null then 1 else 0 end)
		, Division = max(EventMatch.Division)
		, WeightClass = max(EventMatch.WeightClass)
		, Grade = GradeLookup.Grade
		, GradeSort = GradeLookup.Sort
into	#WrestlerData
from	EventWrestlerMatch
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
left join
		EventSchool
on		EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
		and Event.EventState = 'sc'
left join
		School
on		EventSchool.SchoolID = School.ID
outer apply (
		select	Grade = coalesce(NewGrade.Grade, WrestlerGrade.Grade)
				, Sort = coalesce(NewGrade.Sort, WrestlerGrade.Sort)
		from	WrestlerGrade
		left join
				WrestlerGrade NewGrade
		on		WrestlerGrade.Sort + (
					case when month(getdate()) >= 8 then (year(getdate()) + 1) else year(getdate()) end
					- case when month(event.EventDate) >= 8 then (year(event.EventDate) + 1) else year(event.EventDate) end
				) = NewGrade.Sort
		where	EventWrestlerMatch.Grade = WrestlerGrade.Grade
		) GradeLookup
where	EventWrestlerMatch.EventWrestlerID in (select EventWrestlerID from #PagedWrestler)
group by
		EventWrestlerMatch.EventWrestlerID
		, Event.EventName
		, Event.EventDate
		, Event.EventState
		, GradeLookup.Grade
		, GradeLookup.Sort;

;with WrestlerNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Names = '["' + string_agg(lower(WrestlerMatchSource.WrestlerName), '", "') within group (order by WrestlerMatchSource.WrestlerName) + '"]'
	from	(
			select	distinct EventWrestlerID
					, WrestlerName = replace(replace(replace(WrestlerName, '"', ''), '\', ''), '  ', ' ')
			from #WrestlerData
			) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
, TeamNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Teams = '["' + string_agg(lower(WrestlerMatchSource.TeamName), '", "') within group (order by WrestlerMatchSource.TeamName) + '"]'
	from	(
			select	distinct EventWrestlerID
					, TeamName = replace(replace(replace(TeamName, '"', ''), '\', ''), '  ', ' ')
			from #WrestlerData
			) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
, StateAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, States = '["' + string_agg(upper(WrestlerMatchSource.EventState), '", "') within group (order by WrestlerMatchSource.EventState) + '"]'
	from	(select distinct EventWrestlerID, EventState from #WrestlerData) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
, LastEvent as (
	select	WrestlerData.EventWrestlerID
			, RowFilter = row_number() over (partition by WrestlerData.EventWrestlerID order by WrestlerData.EventDate desc)
			, EventName = WrestlerData.EventName
			, EventDate = WrestlerData.EventDate
			, EventState = WrestlerData.EventState
			, WrestlerData.TeamName
			, WeightClass = WrestlerData.WeightClass
	from	#WrestlerData WrestlerData
)
, LastSchoolEvent as (
	select	WrestlerData.EventWrestlerID
			, RowFilter = row_number() over (partition by WrestlerData.EventWrestlerID order by WrestlerData.EventDate desc)
			, SchoolName = WrestlerData.TeamName
			, Division = WrestlerData.Division
			, WeightClass = WrestlerData.WeightClass
	from	#WrestlerData WrestlerData
	where	WrestlerData.IsSchoolTeam = 1
)
, GradeCalculation as (
select	WrestlerData.EventWrestlerID
		, WrestlerData.WrestlerName
		, WrestlerData.Grade
		, RowFilter = row_number() over (partition by WrestlerData.EventWrestlerID order by WrestlerData.GradeSort desc)
from	#WrestlerData WrestlerData
where	len(WrestlerData.Grade) > 0
)
select	WrestlerID = EventWrestler.ID
		, WrestlerName = replace(replace(replace(EventWrestler.WrestlerName, '"', ''), '\', ''), '  ', ' ')
		, Rating = EventWrestler.GlickoRating
		, Deviation = EventWrestler.GlickoDeviation
		, Grade = GradeCalculation.Grade
		, SearchNames = WrestlerNameAggregation.Names
		, SearchTeams = TeamNameAggregation.Teams
		, States = StateAggregation.States
		, LastEventName = LastEvent.EventName
		, LastEventDate = LastEvent.EventDate
		, LastEventState = LastEvent.EventState
		, LastTeamName = LastEvent.TeamName
		, LastWeightClass = LastEvent.WeightClass
		, SchoolName = LastSchoolEvent.SchoolName
		, SchoolDivision = LastSchoolEvent.Division
		, SchoolWeightClass = LastSchoolEvent.WeightClass
from	#PagedWrestler WrestlerPopulation
join	EventWrestler
on		WrestlerPopulation.EventWrestlerID = EventWrestler.ID
join	WrestlerNameAggregation
on		EventWrestler.ID = WrestlerNameAggregation.EventWrestlerID
join	TeamNameAggregation
on		EventWrestler.ID = TeamNameAggregation.EventWrestlerID
join	StateAggregation
on		EventWrestler.ID = StateAggregation.EventWrestlerID
left join
		LastEvent
on		WrestlerPopulation.EventWrestlerID = LastEvent.EventWrestlerID
		and LastEvent.RowFilter = 1
left join
		LastSchoolEvent
on		WrestlerPopulation.EventWrestlerID = LastSchoolEvent.EventWrestlerID
		and LastSchoolEvent.RowFilter = 1
left join
		GradeCalculation
on		WrestlerPopulation.EventWrestlerID = GradeCalculation.EventWrestlerID
		and GradeCalculation.RowFilter = 1
order by
		WrestlerPopulation.LastModified desc
		, EventWrestler.ID;

set nocount off;
