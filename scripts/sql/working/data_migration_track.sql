set nocount on;

-- Description: This script migrates data from TrackWrestling-specific tables
-- (TrackEvent, TrackMatch, TrackWrestler, TrackWrestlerMatch) to the generic system tables
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

-- Step 2: Migrate Events
merge into Event
using (
	select
		ID
		, EventID
		, EventName
		, EventDate
		, EventAddress
		, EventState
		, EndDate
		, IsComplete
		, EventType
	from TrackEvent
) as Source on 1 = 0
when not matched then
	insert (EventSystem, SystemID, EventName, EventDate, EventAddress, EventState, EndDate, EventType, IsComplete, IsExcluded)
	values ('Track', Source.EventID, Source.EventName, Source.EventDate, Source.EventAddress, Source.EventState, Source.EndDate, Source.EventType, Source.IsComplete, 0)
	output inserted.ID, Source.ID into #EventMap (NewID, OldID);

-- Step 3: Migrate Wrestlers
merge into EventWrestler
using (
	select
			ID
		, WrestlerName
	from TrackWrestler
) as Source on 1 = 0
when not matched then
	insert (WrestlerName, GlickoRating, GlickoDeviation)
	values (Source.WrestlerName, NULL, NULL)
	output inserted.ID, Source.ID into #EventWrestlerMap (NewID, OldID);

-- Step 4: Migrate Matches
merge into EventMatch
using (
	select
			tm.ID
		, em.NewID as NewEventID
		, tm.Division
		, tm.WeightClass
		, tm.RoundName
		, tm.WinType
		, tm.Sort
	from TrackMatch as tm
	join #EventMap as em on tm.TrackEventID = em.OldID
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
	, ISNULL(twm.WrestlerName, tw.WrestlerName)
	, ISNULL(twm.Team, tw.TeamName)
	, twm.IsWinner
from TrackWrestlerMatch as twm
join #EventWrestlerMap as w on twm.TrackWrestlerID = w.OldID
join #EventMatchMap as m on twm.TrackMatchID = m.OldID
join TrackWrestler as tw on twm.TrackWrestlerID = tw.ID;

-- Step 6: Clean up the temporary mapping tables.
drop table #EventMap;
drop table #EventMatchMap;
drop table #EventWrestlerMap;

set nocount off;
