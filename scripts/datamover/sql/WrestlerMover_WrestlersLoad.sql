declare @TimespanDays int;
declare @TimespanEventDays int;

set @TimespanDays = ?;
set @TimespanEventDays = ?;

with WrestlerMatchSource as (
	select	EventWrestlerMatch.EventWrestlerID
			, EventWrestlerMatch.WrestlerName
			, coalesce(School.SchoolName, EventWrestlerMatch.TeamName) as TeamName
			, EventWrestlerMatch.ModifiedDate
	from	Event
	join	EventMatch
	on		Event.ID = EventMatch.EventID
	join	EventWrestlerMatch
	on		EventMatch.ID = EventWrestlerMatch.EventMatchID
	left join
			EventSchool
	on		EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
	left join
			School
	on		EventSchool.SchoolID = School.ID
	where	Event.EventDate > dateadd(day, @TimespanEventDays, getdate())
			and (
				Event.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
				or EventWrestlerMatch.ModifiedDate >= dateadd(day, @TimespanDays, getdate())
			)
),
WrestlerNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Names = '["' + string_agg(lower(WrestlerMatchSource.WrestlerName), '", "') within group (order by WrestlerMatchSource.WrestlerName) + '"]'
	from	(select distinct EventWrestlerID, WrestlerName from WrestlerMatchSource) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
),
TeamNameAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, Teams = '["' + string_agg(lower(WrestlerMatchSource.TeamName), '", "') within group (order by WrestlerMatchSource.TeamName) + '"]'
	from	(select distinct EventWrestlerID, TeamName from WrestlerMatchSource) as WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
),
LastModifiedAggregation as (
	select	WrestlerMatchSource.EventWrestlerID
			, max(WrestlerMatchSource.ModifiedDate) as LastModified
	from	WrestlerMatchSource
	group by
			WrestlerMatchSource.EventWrestlerID
)
select	WrestlerID = EventWrestler.ID
		, WrestlerName = EventWrestler.WrestlerName
		, Rating = EventWrestler.GlickoRating
		, Deviation = EventWrestler.GlickoDeviation
		, SearchNames = WrestlerNameAggregation.Names
		, SearchTeams = TeamNameAggregation.Teams
from	EventWrestler
join	LastModifiedAggregation
on		EventWrestler.ID = LastModifiedAggregation.EventWrestlerID
join	WrestlerNameAggregation
on		EventWrestler.ID = WrestlerNameAggregation.EventWrestlerID
join	TeamNameAggregation
on		EventWrestler.ID = TeamNameAggregation.EventWrestlerID
order by
		LastModifiedAggregation.LastModified desc
		, EventWrestler.ID
OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
