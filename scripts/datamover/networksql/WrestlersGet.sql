set nocount on;

declare @TimespanEventDays int;
declare @TimespanDays int;

set @TimespanEventDays = -720 -- ?;

select	id = EventWrestler.ID
		, [name] = EventWrestler.WrestlerName
		, isfortmill = case when FortMillMatch.ID is not null then 1 else 0 end
from	EventWrestler
outer apply (
		select	top 1 EventWrestlerMatch.ID
		from	EventWrestlerMatch
		join	EventSchool
		on		EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
		join	School
		on		EventSchool.SchoolID = School.ID
		where	EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
				and School.SchoolName = 'Fort Mill'
		) FortMillMatch
cross apply (
		select	EventWrestlerMatch.ID
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		where	EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
				and Event.EventDate > dateadd(day, @TimespanEventDays, getdate())
		) ValidEvent
group by
		EventWrestler.ID
		, EventWrestler.WrestlerName
		, case when FortMillMatch.ID is not null then 1 else 0 end

set nocount off;
