UNWIND $batch as batchRow
MATCH (sourceNode: Wrestler {id: batchRow.sourceid})
MATCH (targetNode: Wrestler {id: batchRow.targetid})
MERGE (sourceNode)-[wrestledRelationship: Wrestled { matchID: batchRow.matchid }]->(targetNode)
SET wrestledRelationship.eventDate = batchRow.EventDate
	, wrestledRelationship.IsWinner = batchRow.IsWinner
	, wrestledRelationship.WinType = batchRow.WinType
