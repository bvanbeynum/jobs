select	SchoolID = School.ID
		, School.SchoolName
		, School.Classification
		, School.Region
		, LookupNames = '["' + string_agg(EventSchool.eventschoolName, '", "') within group (order by EventSchool.eventschoolName) + '"]'
from	School
join	EventSchool
on		School.ID = EventSchool.SchoolID
group by
		School.ID
		, School.SchoolName
		, School.Classification
		, School.Region
order by
		School.Classification desc
		, School.Region
		, School.SchoolName;
