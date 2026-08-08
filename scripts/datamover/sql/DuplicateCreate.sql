if object_id('tempdb..#Duplicates') is not null
	drop table #Duplicates

create table #Duplicates (
	SaveWrestlerID int
	, DuplicateWrestlerID int
);
