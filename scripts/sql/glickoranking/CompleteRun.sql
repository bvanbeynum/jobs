update	TSSummary
set		RunDate = getdate()
		, ModifiedDate = getdate()
where	ID = ?;