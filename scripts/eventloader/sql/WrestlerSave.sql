set nocount on;

declare @WrestlerID int;
declare @WrestlerName varchar(255);
declare @TeamName varchar(255);

set @WrestlerName = ?;
set @TeamName = ?;

select	@WrestlerID = min(EventWrestlerMatch.EventWrestlerID)
from	EventWrestlerMatch
cross apply (
		select	LookupName = replace(trim(@WrestlerName), ' ', '')
				, LookupTeam = replace(replace(replace(replace(replace(@TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
				, WrestlerName = replace(trim(EventWrestlerMatch.WrestlerName), ' ', '')
				, TeamName = replace(replace(replace(replace(replace(EventWrestlerMatch.TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
		) NameCleanse
where	NameCleanse.LookupName = NameCleanse.WrestlerName
		and NameCleanse.LookupTeam = NameCleanse.TeamName;

if @WrestlerID is null
begin
	insert	EventWrestler (
			WrestlerName
			)
	values	(
			@WrestlerName
			);

	select	@WrestlerID = scope_identity();
	
end
else
begin

	-- Set the name on the Wrestler table to the most popular name used if there are duplicates

	declare @NewName varchar(255);

	select	@NewName = WrestlerName
	from	(	
			select	top 1 EventWrestlerMatch.WrestlerName
			from	EventWrestlerMatch
			join	EventMatch
			on		EventWrestlerMatch.EventMatchID = EventMatch.ID
			join	Event
			on		EventMatch.EventID = Event.ID
			where	EventWrestlerID = @WrestlerID
			group by
					EventWrestlerMatch.WrestlerName
			order by
					count(distinct Event.ID) desc
					, min(Event.EventDate)
					, min(Event.ID)
			) TopWrestlerName

	update	EventWrestler
	set		WrestlerName = coalesce(@NewName, WrestlerName)
			, ModifiedDate = getdate()
	where	EventWrestler.ID = @WrestlerID;

end

select	@WrestlerID;

set nocount off;