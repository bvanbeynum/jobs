select	Wrester1ID = TSWrestler.FloWrestlerID
		, Wrestler1Rating = TSWrestler.Rating
		, Wrestler1Deviation = TSWrestler.Deviation
		, Wrester2ID = OtherWrestler.FloWrestlerID
		, Wrestler2Rating = OtherWrestler.Rating
		, Wrestler2Deviation = OtherWrestler.Deviation
from	TSMatch
join	TSWrestler
on		TSMatch.TSWrestlerID = TSWrestler.ID
join	TSMatch OtherMatch
on		TSMatch.MatchID = OtherMatch.MatchID
		and TSMatch.EventID = OtherMatch.EventID
		and TSMatch.IsFlo = OtherMatch.IsFlo
		and TSMatch.TSWrestlerID <> OtherMatch.TSWrestlerID
join	TSWrestler OtherWrestler
on		OtherMatch.TSWrestlerID = OtherWrestler.ID
where	TSWrestler.TSSummaryID = (select max(id) from TSSummary where RunDate is not null)
		and TSWrestler.FloWrestlerID is not null
		and OtherWrestler.FloWrestlerID is not null
group by
		TSWrestler.FloWrestlerID
		, TSWrestler.Rating
		, TSWrestler.Deviation
		, OtherWrestler.FloWrestlerID
		, OtherWrestler.Rating
		, OtherWrestler.Deviation;
