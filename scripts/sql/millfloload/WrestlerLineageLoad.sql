set nocount on;

;with lineagecte as (
select	WrestlerLoadBatch.WrestlerID
		, WrestlerLineage.Tier
		, WrestlerLineage.Wrestler2ID
		, WrestlerLineage.Wrestler2Team
		, Packet = cast(
			'{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerLineage.Wrestler1Flo as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerLineage.Wrestler1Name + '",' +
			'"wrestler1Team": "' + WrestlerLineage.wrestler1Team + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(WrestlerLineage.Wrestler2Flo as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + WrestlerLineage.Wrestler2Name + '",' +
			'"wrestler2Team": "' + WrestlerLineage.wrestler2Team + '",' +
			'"isWinner": ' + case when WrestlerLineage.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(WrestlerLineage.Tier as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerLineage.EventDate, 111), '/', '-') + '"' +
			'}'
			as varchar(max))
from	#WrestlerLoadBatch WrestlerLoadBatch
join	WrestlerLineage
on		WrestlerLoadBatch.WrestlerID = WrestlerLineage.FloWrestlerID
where	WrestlerLineage.Tier = 1
union all
select	lineagecte.WrestlerID
		, opponents.Tier
		, opponents.Wrestler2ID
		, opponents.Wrestler2Team
		, Lineage = lineagecte.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(opponents.Wrestler1Flo as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + opponents.Wrestler1Name + '",' +
			'"wrestler1Team": "' + opponents.wrestler1Team + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(opponents.Wrestler2Flo as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + opponents.Wrestler2Name + '",' +
			'"wrestler2Team": "' + opponents.wrestler2Team + '",' +
			'"isWinner": ' + case when opponents.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(opponents.Tier as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), opponents.EventDate, 111), '/', '-') + '"' +
			'}'
from	lineagecte
join	WrestlerLineage opponents
on		lineagecte.Wrestler2ID = opponents.Wrestler1ID
		and lineagecte.Tier = opponents.Tier - 1
		and lineagecte.WrestlerID = opponents.FloWrestlerID
)
select	lineagecte.WrestlerID
		, Packet = '[' + string_agg('[' + lineagecte.Packet + ']', ',') + ']'
from	lineagecte
where	lineagecte.Wrestler2Team = 'fort mill'
group by
		lineagecte.WrestlerID;

set nocount off;