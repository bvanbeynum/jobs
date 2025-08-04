set nocount on;

-- Description: This script migrates data from FloWrestling-specific tables
-- (FloMeet, FloMatch, FloWrestler, FloWrestlerMatch) to the generic system tables
-- (Event, Match, Wrestler, WrestlerMatch).
-- It uses temporary mapping tables to preserve relational integrity after new
-- primary keys are generated for the destination tables.

-- Step 0: Truncate target tables to ensure a clean load.
delete from EventWrestlerMatch;
delete from  EventMatch;
delete from  Event;
delete from  EventWrestler;

-- Step 1: Create temporary tables to map old IDs to new IDs.
create table #EventMap (OldID INT, NewID INT);
create table #EventMatchMap (OldID INT, NewID INT);
create table #EventWrestlerMap (OldID INT, NewID INT);

-- Step 2: Migrate Events (Meets)
merge into Event
using (
	select
			ID
		, FlowID
		, MeetName
		, StartTime
		, ISNULL(LocationCity, '') + ', ' + ISNULL(LocationState, '') as EventAddress
		, LocationState
		, EndTime
		, IsComplete
		, IsExcluded
	from FloMeet
	where IsExcluded = 0
) as Source on 1 = 0
when not matched then
	insert (EventSystem, SystemID, EventName, EventDate, EventAddress, EventState, EndDate, IsComplete, IsExcluded)
	values ('Flo', Source.FlowID, Source.MeetName, Source.StartTime, Source.EventAddress, Source.LocationState, Source.EndTime, Source.IsComplete, Source.IsExcluded)
	output inserted.ID, Source.ID into #EventMap (NewID, OldID);

-- Step 3: Migrate Wrestlers
merge into EventWrestler
using (
	select
			ID
		, RTRIM(LTRIM(FirstName)) + ' ' + RTRIM(LTRIM(LastName)) as WrestlerName
	from FloWrestler
) as Source on 1 = 0
when not matched then
	insert (WrestlerName, GlickoRating, GlickoDeviation)
	values (Source.WrestlerName, NULL, NULL)
	output inserted.ID, Source.ID into #EventWrestlerMap (NewID, OldID);

-- Step 4: Migrate Matches
merge into EventMatch
using (
	select
			fm.ID
		, em.NewID as NewEventID
		, fm.Division
		, fm.WeightClass
		, fm.RoundName
		, fm.WinType
		, fm.Sort
	from FloMatch as fm
	join #EventMap as em on fm.FloMeetID = em.OldID
) as Source on 1 = 0
when not matched then
	insert (EventID, Division, WeightClass, RoundName, WinType, Sort)
	values (Source.NewEventID, Source.Division, Source.WeightClass, Source.RoundName, Source.WinType, Source.Sort)
	output inserted.ID, Source.ID into #EventMatchMap (NewID, OldID);

-- Step 5: Migrate Wrestler-Match relationships
insert into EventWrestlerMatch (EventWrestlerID, EventMatchID, WrestlerName, TeamName, IsWinner)
select
	w.NewID
	, m.NewID
	, ISNULL(fwm.FirstName + ' ' + fwm.LastName, fw.FirstName + ' ' + fw.LastName)
	, ISNULL(fwm.Team, fw.TeamName)
	, fwm.IsWinner
from FloWrestlerMatch as fwm
join #EventWrestlerMap as w on fwm.FloWrestlerID = w.OldID
join #EventMatchMap as m on fwm.FloMatchID = m.OldID
join FloWrestler as fw on fwm.FloWrestlerID = fw.ID;

-- Step 6: Clean up the temporary mapping tables.
drop table #EventMap;
drop table #EventMatchMap;
drop table #EventWrestlerMap;

set nocount off;