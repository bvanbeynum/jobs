set nocount on;

delete
from	GlickoPrediction;

insert	GlickoPrediction (
		Wrestler1FloID
		, Wrestler2FloID
		, Probability
		)
select	Wrestler1ID
		, Wrestler2ID
		, Probability
from	#GlickPredict_Stage;

set nocount off;