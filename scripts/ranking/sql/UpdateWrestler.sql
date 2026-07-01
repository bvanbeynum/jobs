update	EventWrestler
set		GlickoRating = ?
		, GlickoDeviation = ?
		, JVRating = ?
		, JVDeviation = ?
		, MSRating = ?
		, MSDeviation = ?
		, GirlsRating = ?
		, GirlsDeviation = ?
		, ModifiedDate = getdate()
where	ID = ?;
