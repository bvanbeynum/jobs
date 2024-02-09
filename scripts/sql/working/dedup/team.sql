
declare @TeamName varchar(max);
set @TeamName = 'byrnes';

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

update	FloWrestlerMatch
set		team = 'Hillcrest'
where	Team in ('Hillcrest B')

update	TrackWrestlerMatch
set		team = 'Byrnes'
where	Team in ('James F Byrnes')

commit

rollback
