
if object_id('tempdb..#GlickPredict_Stage') is not null
	drop table #GlickPredict_Stage;

create table #GlickPredict_Stage (
	Wrestler1ID int
	, Wrestler2ID int
	, Probability decimal(18,9)
);
