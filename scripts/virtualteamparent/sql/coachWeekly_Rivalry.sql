; with SchoolEvents as (
select	school.Region
		, School.SchoolName
		, WeekEvents.SchoolID
		, WeekEvents.EventName
		, Wrestlers = count(distinct EventWrestlerMatch.EventWrestlerID)
from	#WeekEvents WeekEvents
join	School
on		WeekEvents.SchoolID = School.ID
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
where	school.Classification like '5a%'
		and School.Region < 5
group by
		School.SchoolName
		, school.Region
		, WeekEvents.SchoolID
		, WeekEvents.EventName
),
SchoolWrestlers as (
select	Rank = rank() over (partition by EventRatings.SchoolID order by EventRatings.Rating desc)
		, EventRatings.SchoolID
		, Wrestler = EventWrestler.WrestlerName
		, EventRatings.WeightClass
		, EventRatings.Rating
from	#EventRatings EventRatings
join	EventWrestler
on		EventRatings.EventWrestlerID = EventWrestler.ID
group by
		EventRatings.SchoolID
		, EventWrestler.WrestlerName
		, EventRatings.WeightClass
		, EventRatings.Rating
),
DistinctSchoolEvents as (
select	Region
		, SchoolID
		, School = SchoolName
		, Events = string_agg(EventName + ' (' + cast(Wrestlers as varchar(max)) + ' wrestlers)', ', ') within group (order by Wrestlers desc)
from	SchoolEvents
group by
		Region
		, SchoolID
		, SchoolName
),
TopWrestlers as (
select	SchoolWrestlers.SchoolID
		, TopWrestlers = string_agg(SchoolWrestlers.Wrestler + ' (' + SchoolWrestlers.WeightClass + ')', ', ') within group (order by SchoolWrestlers.Rank)
from	SchoolWrestlers
where	SchoolWrestlers.Rank <= 5
group by
		SchoolWrestlers.SchoolID
)
select	DistinctSchoolEvents.Region
		, DistinctSchoolEvents.school
		, '* Events: ' + DistinctSchoolEvents.Events + '\n\n* Top Wrestlers: ' + TopWrestlers.TopWrestlers
from	DistinctSchoolEvents
join	TopWrestlers
on		DistinctSchoolEvents.SchoolID = TopWrestlers.SchoolID
order by
		Region
		, DistinctSchoolEvents.School;
