
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

declare @NewName varchar(max);
declare @DupName varchar(max);

set @NewName = 'Darkhorse';
set @DupName = 'Darkhorse Wrestling';

select	FloWrestlers = (select count(distinct FloWrestlerID) from FloWrestlerMatch where team = @DupName)
		, FloMatches = (select count(0) from FloWrestlerMatch where Team = @DupName)
		, TrackWrestlers = (select count(distinct TrackWrestlerID) from TrackWrestlerMatch where Team = @DupName)
		, trackMatches = (select count(0) from TrackWrestlerMatch where team = @DupName);

update	FloWrestler
set		ModifiedDate = getdate()
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
where	FloWrestlerMatch.Team = @DupName;

update	FloWrestlerMatch
set		team = @NewName
		, ModifiedDate = getdate()
where	Team = @DupName;

update	TrackWrestler
set		ModifiedDate = getdate()
from	TrackWrestler
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
where	TrackWrestlerMatch.Team = @DupName;

update	TrackWrestlerMatch
set		Team = @NewName
		, ModifiedDate = getdate()
where	Team = @DupName;

/*

commit;

rollback;

*/
