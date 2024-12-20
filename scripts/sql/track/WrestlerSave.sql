set nocount on;

declare @WrestlerID int;
declare @WrestlerName varchar(255);
declare @TeamName varchar(255);

set @WrestlerName = ?;
set @TeamName = ?;

select	@WrestlerID = min(TrackWrestlerMatch.TrackWrestlerID)
from	TrackWrestlerMatch
cross apply (
		select	LookupName = replace(trim(@FirstName), ' ', '') + replace(trim(@LastName), ' ', '')
				, LookupTeam = replace(replace(replace(replace(replace(@TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
				, WrestlerName = replace(trim(TrackWrestlerMatch.WrestlerName), ' ', '')
				, TeamName = replace(replace(replace(replace(replace(TrackWrestlerMatch.Team, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
		) NameCleanse
left join
		ExternalTeam
on		TrackWrestlerMatch.Team = ExternalTeam.Team
where	NameCleanse.LookupName = NameCleanse.WrestlerName
		and NameCleanse.LookupTeam = NameCleanse.TeamName;

if @WrestlerID is null
begin

	insert	TrackWrestler (
			WrestlerName
			, TeamName
			)
	values	(
			@WrestlerName
			, @TeamName
			);

	select	@WrestlerID = scope_identity();
end

select	@WrestlerID;

set nocount off;