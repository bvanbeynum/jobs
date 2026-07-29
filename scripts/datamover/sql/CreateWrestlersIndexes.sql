-- Index on EventWrestlerMatch for fast timespan filtering and wrestler grouping
if not exists (select 1 from sys.indexes where name = 'IX_EventWrestlerMatch_ModifiedDate_EventWrestlerID' and object_id = object_id('EventWrestlerMatch'))
begin
	create nonclustered index IX_EventWrestlerMatch_ModifiedDate_EventWrestlerID
	on EventWrestlerMatch (ModifiedDate, EventWrestlerID);
end

-- Index on EventWrestlerMatch for fast wrestler lookup with covering columns
if not exists (select 1 from sys.indexes where name = 'IX_EventWrestlerMatch_EventWrestlerID' and object_id = object_id('EventWrestlerMatch'))
begin
	create nonclustered index IX_EventWrestlerMatch_EventWrestlerID
	on EventWrestlerMatch (EventWrestlerID)
	include (EventMatchID, WrestlerName, TeamName, Grade);
end

-- Index on EventSchool to speed up string join matching with School
if not exists (select 1 from sys.indexes where name = 'IX_EventSchool_EventSchoolName' and object_id = object_id('EventSchool'))
begin
	create nonclustered index IX_EventSchool_EventSchoolName
	on EventSchool (EventSchoolName)
	include (SchoolID);
end
