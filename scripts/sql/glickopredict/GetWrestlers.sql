set nocount on;

declare @Wrestlers table (
	FloWrestlerID int
	, Rating decimal(18,9)
	, Deviation decimal(18,9)
);

insert	@Wrestlers (
		FloWrestlerID
		, Rating
		, Deviation
		)
select	FloWrestlerMatch.FloWrestlerID
		, TSWrestler.Rating
		, TSWrestler.Deviation
from	(
		select	distinct TeamName
		from	xx_TeamLineup TeamLineup
		) Teams
join	FloWrestlerMatch
on		Teams.TeamName = FloWrestlerMatch.Team
join	TSWrestler
on		FloWrestlerMatch.FloWrestlerID = TSWrestler.FloWrestlerID
		and TSWrestler.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
group by
		FloWrestlerMatch.FloWrestlerID
		, TSWrestler.Rating
		, TSWrestler.Deviation;

select	Wrester1ID = Wrestler1.FloWrestlerID
		, Wrestler1Rating = Wrestler1.Rating
		, Wrestler1Deviation = Wrestler1.Deviation
		, Wrester2ID = Wrestler2.FloWrestlerID
		, Wrestler2Rating = Wrestler2.Rating
		, Wrestler2Deviation = Wrestler2.Deviation
from	@Wrestlers Wrestler1
join	@Wrestlers Wrestler2
on		Wrestler1.FloWrestlerID <> Wrestler2.FloWrestlerID
group by
		Wrestler1.FloWrestlerID
		, Wrestler1.Rating
		, Wrestler1.Deviation
		, Wrestler2.FloWrestlerID
		, Wrestler2.Rating
		, Wrestler2.Deviation;

set nocount off;