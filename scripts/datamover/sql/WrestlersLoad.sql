declare @TimespanDays int;

set @TimespanDays = ?;

with WrestlerPopulation as (
	select	EventWrestlerMatch.EventWrestlerID
			, LastModified = max(EventWrestlerMatch.ModifiedDate)
	from	EventWrestlerMatch
	where	EventWrestlerMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
	group by
			EventWrestlerMatch.EventWrestlerID
)
, WrestlerData as (
	select	EventWrestlerMatch.EventWrestlerID
			, Event.EventDate
			, Event.EventState
			, WrestlerName = max(EventWrestlerMatch.WrestlerName)
			, TeamName = max(coalesce(School.SchoolName, EventWrestlerMatch.TeamName))
			, IsSchoolTeam = max(case when School.ID is not null then 1 else 0 end)
			, Division = max(EventMatch.Division)
			, WeightClass = max(EventMatch.WeightClass)
			, Grade = max(EventWrestlerMatch.Grade)
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
	where	EventWrestlerMatch.EventWrestlerID in (select EventWrestlerID from WrestlerPopulation)
	group by
			EventWrestlerMatch.EventWrestlerID
			, Event.EventDate
			, Event.EventState
)
, WrestlerNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Names = '["' + string_agg(lower(WrestlerMatchSource.WrestlerName), '", "') within group (order by WrestlerMatchSource.WrestlerName) + '"]'
	from	(select distinct EventWrestlerID, WrestlerName from WrestlerData) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
, TeamNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Teams = '["' + string_agg(lower(WrestlerMatchSource.TeamName), '", "') within group (order by WrestlerMatchSource.TeamName) + '"]'
	from	(select distinct EventWrestlerID, TeamName from WrestlerData) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
, LastEvent as (
	select	WrestlerData.EventWrestlerID
			, RowFilter = row_number() over (partition by WrestlerData.EventWrestlerID order by WrestlerData.EventDate desc)
			, WeightClass = WrestlerData.WeightClass
	from	WrestlerData
)
, LastSchoolEvent as (
	select	WrestlerData.EventWrestlerID
			, RowFilter = row_number() over (partition by WrestlerData.EventWrestlerID order by WrestlerData.EventDate desc)
			, SchoolName = WrestlerData.TeamName
			, Division = WrestlerData.Division
			, WeightClass = WrestlerData.WeightClass
	from	WrestlerData
	where	WrestlerData.IsSchoolTeam = 1
)
select	WrestlerID = EventWrestler.ID
		, WrestlerName = EventWrestler.WrestlerName
		, Rating = EventWrestler.GlickoRating
		, Deviation = EventWrestler.GlickoDeviation
		, Grade = WrestlerGrade.Grade
		, SearchNames = WrestlerNameAggregation.Names
		, SearchTeams = TeamNameAggregation.Teams
		, LastWeightClass = LastEvent.WeightClass
		, SchoolName = LastSchoolEvent.SchoolName
		, SchoolDivision = LastSchoolEvent.Division
		, SchoolWeightClass = LastSchoolEvent.WeightClass
from	WrestlerPopulation
join	EventWrestler
on		WrestlerPopulation.EventWrestlerID = EventWrestler.ID
join	WrestlerNameAggregation
on		EventWrestler.ID = WrestlerNameAggregation.EventWrestlerID
join	TeamNameAggregation
on		EventWrestler.ID = TeamNameAggregation.EventWrestlerID
left join
		LastEvent
on		WrestlerPopulation.EventWrestlerID = LastEvent.EventWrestlerID
		and LastEvent.RowFilter = 1
left join
		LastSchoolEvent
on		WrestlerPopulation.EventWrestlerID = LastSchoolEvent.EventWrestlerID
		and LastSchoolEvent.RowFilter = 1
outer apply (
		select	top 1 WrestlerData.Grade
		from	WrestlerData
		where	WrestlerPopulation.EventWrestlerID = WrestlerData.EventWrestlerID
				and len(WrestlerData.Grade) > 0
		order by
				WrestlerData.EventDate desc
		) WrestlerGrade
order by
		WrestlerPopulation.LastModified desc
		, EventWrestler.ID
OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
