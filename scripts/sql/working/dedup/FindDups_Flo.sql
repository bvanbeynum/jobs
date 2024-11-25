
select	GroupID
		, WrestlerID
		, FirstName
		, LastName
		, WrestlerTeams.Teams
from	(
		select	GroupID = rank() over (order by FloWrestler.FirstName, FloWrestler.LastName, FloWrestlerMatch.Team)
				, WrestlerID = FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestlerMatch.Team
				, Wrestlers = count(0) over (partition by FloWrestler.FirstName, FloWrestler.LastName, FloWrestlerMatch.Team)
		from	FloWrestler
		join	FloWrestlerMatch
		on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
		group by
				FloWrestler.ID
				, FloWrestler.FirstName
				, FloWrestler.LastName
				, FloWrestlerMatch.Team
		) DupWrestlers
cross apply (
		select	Teams = string_agg(team, ', ')
		from	(
				select	distinct FloWrestlerMatch.Team
				from	FloWrestlerMatch
				where	DupWrestlers.WrestlerID = FloWrestlerMatch.FloWrestlerID
				) WrestlerTeamsGroup
		) WrestlerTeams
where	Wrestlers > 1
order by
		GroupID
		, WrestlerID
		, FirstName
		, LastName
		, Team
