set nocount on;

delete
from	#Wrestlers
from	#Wrestlers Wrestlers
join	#WrestlerLoadBatch Batch
on		Wrestlers.WrestlerID = Batch.WrestlerID;

delete
from	#WrestlerLoadBatch;

set nocount off;