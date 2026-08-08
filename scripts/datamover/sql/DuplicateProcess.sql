set nocount on;

begin transaction

begin try

	-- Convert all the duplicate's matches to the primary
	update  EventWrestlerMatch
	set		EventWrestlerID = Duplicates.SaveWrestlerID
			, ModifiedDate = getdate()
	from	EventWrestlerMatch
	join	#Duplicates Duplicates
	on		EventWrestlerMatch.EventWrestlerID = Duplicates.DuplicateWrestlerID;

	-- Delete all the duplicates
	delete
	from	EventWrestler
	from	EventWrestler
	join	#Duplicates Duplicates
	on		EventWrestler.ID = Duplicates.DuplicateWrestlerID;

	-- Pick the best wrestler name based on the most common name
	update  EventWrestler
	set		WrestlerName = TopWrestlerName.WrestlerName
			, ModifiedDate = getdate()
	from	EventWrestler
	cross apply (
			select  top 1 EventWrestlerMatch.WrestlerName
			from	EventWrestlerMatch
			join	EventMatch
			on		EventWrestlerMatch.EventMatchID = EventMatch.ID
			join	Event
			on		EventMatch.EventID = Event.ID
			where   EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
			group by
					EventWrestlerMatch.WrestlerName
			order by
					count(distinct Event.ID) desc
					, min(Event.EventDate)
					, min(Event.ID)
			) TopWrestlerName
	where   EventWrestler.ID in (
				select  distinct SaveWrestlerID
				from	#Duplicates
			);

	-- Delete all orphan wrestlers
	delete
	from	EventWrestler
	from	EventWrestler
	left join
			EventWrestlerMatch
	on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
	where	EventWrestlerMatch.EventWrestlerID is null;

	commit

end try
begin catch

	rollback;

	throw;
end catch;

set nocount off;
