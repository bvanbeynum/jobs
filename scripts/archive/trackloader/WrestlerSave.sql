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

select	@WrestlerID;

set nocount off;