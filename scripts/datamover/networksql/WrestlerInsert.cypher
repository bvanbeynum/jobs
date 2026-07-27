UNWIND $batch as batchRow
MERGE (wrestlerNode: Wrestler {id: batchRow.id})
SET wrestlerNode.name = batchRow.name
	, wrestlerNode.IsFortMill = batchRow.isfortmill
