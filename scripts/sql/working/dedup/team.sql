
declare @TeamName varchar(max);
set @TeamName = 'greenwood';

select	Team
		, Wrestlers = count(distinct FloWrestlerID)
from	FloWrestlerMatch
where	Team like '%' + @TeamName + '%'
group by
		team
order by
		Wrestlers desc

select	Team
		, Wrestlers = count(distinct TrackWrestlerID)
from	TrackWrestlerMatch
where	Team like '%' + @TeamName + '%'
group by
		team
order by
		Wrestlers desc

return;

select @@trancount;

begin transaction

-- update	FloWrestlerMatch
-- set		team = 'Greenwood'
-- where	Team in ('Greenwood Grapplers')

-- update	FloWrestler
-- set		ModifiedDate = getdate()
-- from	FloWrestler
-- join	FloWrestlerMatch
-- on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
-- where	FloWrestlerMatch.team = 'Greenwood Eagles'

update	TrackWrestlerMatch
set		team = 'Greenwood'
where	Team in ('Greenwood Eagles')

update	TrackWrestler
set		ModifiedDate = getdate()
from	TrackWrestler
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
where	TrackWrestlerMatch.team = 'Greenwood Eagles'

commit

rollback
