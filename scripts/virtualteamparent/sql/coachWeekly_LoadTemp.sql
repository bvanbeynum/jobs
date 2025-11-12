insert	#WeekEvents (
		EventID
		, EventDate
		, EventName
		, SchoolID
		, SchoolName
		, EventSchoolName
		)
select	EventID = Event.ID
		, Event.EventDate
		, Event.EventName
		, SchoolFilter.SchoolID
		, SchoolFilter.SchoolName
		, SchoolFilter.EventSchoolName
from	Event
cross apply (
		select	distinct 
				SchoolID = School.ID
				, School.SchoolName
				, EventSchool.EventSchoolName
		from	Event EventLookup
		join	EventMatch
		on		EventLookup.ID = EventMatch.EventID
		join	EventWrestlerMatch
		on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		join	EventSchool
		on		EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
		join	School
		on		EventSchool.SchoolID = School.ID
		where	EventLookup.ID = Event.ID
				and School.Classification like '5a%'
		) SchoolFilter
where	event.EventDate between dateadd(d, -6, :loadDate) and :loadDate
group by
		Event.ID
		, Event.EventDate
		, Event.EventName
		, SchoolFilter.SchoolID
		, SchoolFilter.SchoolName
		, SchoolFilter.EventSchoolName
order by
		Event.EventDate desc
		, Event.EventName;

-- Weekly Ratings

insert	#EventRatings (
		EventID
		, EventName
		, SchoolID
		, Division
		, WeightClass
		, EventWrestlerID
		, Rating
		)
select	distinct WeekEvents.EventID
		, WeekEvents.EventName
		, WeekEvents.SchoolID
		, Division = coalesce(EventMatch.Division, 'hs')
		, EventMatch.WeightClass
		, WrestlerRating.EventWrestlerID
		, WrestlerRating.Rating
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
join	WrestlerRating
on		EventWrestlerMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
		and WeekEvents.EventDate between dateadd(day, -6, WrestlerRating.PeriodEndDate) and WrestlerRating.PeriodEndDate
where	coalesce(EventMatch.Division, 'hs') like 'hs%'
		or EventMatch.Division = 'jv'
		or EventMatch.Division like '%high school%';
