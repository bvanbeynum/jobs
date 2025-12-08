set nocount on;

select	*
into	#NamePick
from	(
		select	EventWrestlerMatch.EventWrestlerID
				, WrestlerName = EventWrestlerMatch.WrestlerName
				, ExistingName = EventWrestler.WrestlerName
				, TopPick = row_number() over (partition by EventWrestlerMatch.EventWrestlerID order by count(distinct Event.ID) desc, min(Event.EventDate), min(Event.ID), count(distinct EventWrestlerMatch.ID) desc)
				, events = count(distinct Event.ID), firstevent = min(Event.EventDate), firstadd = min(Event.ID), mostmatches =  count(distinct EventWrestlerMatch.ID)
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		where	EventWrestlerMatch.InsertDate > getdate() - 1
		group by
				EventWrestlerMatch.EventWrestlerID
				, EventWrestlerMatch.WrestlerName
				, EventWrestler.WrestlerName
				, EventWrestlerMatch.WrestlerName
		) WrestlerNames
where	TopPick = 1
		and WrestlerName <> ExistingName;

update	EventWrestler
set		WrestlerName = NamePick.WrestlerName
		, ModifiedDate = getdate()
from	EventWrestler
join	#NamePick NamePick
on		EventWrestler.ID = NamePick.EventWrestlerID;

set nocount off;