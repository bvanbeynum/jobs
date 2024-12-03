/*

commit;

rollback;

*/



if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16
