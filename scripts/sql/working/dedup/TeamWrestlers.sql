
select	top 100 PrimaryTeam = FloWrestlerMatch.Team
		, OtherTeam = OtherTeam.Team
		, PrimaryWrestlers = count(distinct FloWrestlerMatch.FloWrestlerID)
		, PrimaryMeets = count(distinct FloMatch.FloMeetID)
		, OthersWrestlers = count(distinct OtherTeam.FloWrestlerID)
		, Records = count(distinct OtherTeam.ID)
from	FloWrestlerMatch
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
left join
		FloWrestlerMatch OtherTeam
on		FloWrestlerMatch.FloWrestlerID = OtherTeam.FloWrestlerID
		and FloWrestlerMatch.Team <> OtherTeam.Team
group by
		FloWrestlerMatch.Team
		, OtherTeam.Team
order by
		OthersWrestlers desc
		, PrimaryMeets desc


return;

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

update	FloWrestlerMatch
set		team = 'Lionsheart'
		, ModifiedDate = getdate()
where	Team = 'Lionsheart wrestling club'

commit;

rollback;
