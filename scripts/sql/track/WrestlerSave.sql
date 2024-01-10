set nocount on;

declare @WrestlerID int;
declare @WrestlerName varchar(255);
declare @TeamName varchar(255);

set @WrestlerName = ?;
set @TeamName = ?;

select	@WrestlerID = Wrestler.TrackWrestlerID
from	(
		select	TrackWrestlerID = TrackWrestler.ID
				, RowFilter = row_number() over (
					order by
						case 
						when NameCleanse.LookupTeam = WrestlerTeam.TeamCleanse then 1
						when WrestlerTeam.IsHighSchool = 1 then 2
						when WrestlerTeam.IsMiddleSchool = 1 then 3
						when WrestlerTeam.IsClub = 1 then 4
						when WrestlerTeam.IsState = 1 then 5
						else TrackWrestler.ID end
					)
				, TrackWrestler.WrestlerName
				, WrestlerTeam.Team
				, IsHighSchool
				, IsMiddleSchool
				, IsClub
				, IsState
		from	TrackWrestler
		cross apply (
				select	LookupName = replace(trim(@WrestlerName), ' ', '')
						, LookupTeam = replace(replace(replace(replace(replace(@TeamName, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
						, WrestlerName = replace(trim(TrackWrestler.WrestlerName), ' ', '')
				) NameCleanse
		join	(
				select	TrackWrestlerMatch.TrackWrestlerID
						, TrackWrestlerMatch.Team
						, TeamCleanse = replace(replace(replace(replace(replace(TrackWrestlerMatch.Team, '-', ''), '/', ''), '.', ''), ',', ''), ' ', '')
						, ExternalTeam.IsHighSchool
						, ExternalTeam.IsMiddleSchool
						, ExternalTeam.IsClub
						, ExternalTeam.IsState
						, Matches = count(distinct TrackWrestlerMatch.TrackMatchID)
				from	TrackWrestlerMatch
				left join
						ExternalTeam
				on		TrackWrestlerMatch.Team = ExternalTeam.Team
				group by
						TrackWrestlerMatch.TrackWrestlerID
						, TrackWrestlerMatch.Team
						, ExternalTeam.IsHighSchool
						, ExternalTeam.IsMiddleSchool
						, ExternalTeam.IsClub
						, ExternalTeam.IsState
				) WrestlerTeam
		on		TrackWrestler.ID = WrestlerTeam.TrackWrestlerID
		where	NameCleanse.LookupName = NameCleanse.WrestlerName
				and (
					NameCleanse.LookupTeam like '%' + WrestlerTeam.TeamCleanse + '%'
					or WrestlerTeam.TeamCleanse like '%' + NameCleanse.LookupTeam + '%'
				)
		) Wrestler
where	Wrestler.RowFilter = 1;

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