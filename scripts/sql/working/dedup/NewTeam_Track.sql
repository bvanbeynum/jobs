
with ExistingTeams as (
select	Team
from	TrackWrestlerMatch
group by
		Team
having	min(InsertDate) < getdate() - 7
)
select	NewTeams.TeamID
		, NewTeam = NewTeams.Team
		, ExistingTeam = ExistingTeams.Team
from	(
		select	TeamID = row_number() over (order by TrackWrestlerMatch.Team)
				, TrackWrestlerMatch.Team
		from	TrackWrestlerMatch
		group by
				TrackWrestlerMatch.Team
		having	min(TrackWrestlerMatch.InsertDate) > getdate() - 7
		) NewTeams
cross apply string_split(NewTeams.Team, ' ') SplitTable
left join
		ExistingTeams
on		ExistingTeams.Team = SplitTable.[value]
		or ExistingTeams.Team like SplitTable.[value] + ' %'
		or ExistingTeams.Team like '% ' + SplitTable.[value] + '%'
where	SplitTable.[value] not in ('high', 'school', 'wrestling', 'club', 'middle', 'academy', 'county', 'Catholic', 'valley', 'Wresting', 'carolina')
		and len(SplitTable.[value]) > 3
group by
		NewTeams.TeamID
		, NewTeams.Team
		, ExistingTeams.Team
order by
		NewTeams.Team
		, ExistingTeams.Team


