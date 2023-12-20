
if object_id('tempdb..#AllMatches') is not null
	drop table #AllMatches;

create table #AllMatches (
	MatchSort integer
	, MatchID integer
	, WinnerID integer
	, LoserID integer
);

insert ELOSummary (Title)
values ('Test');

declare	@SummaryID int;

select @SummaryID = scope_identity();

set nocount on;

delete
from	ELORank
where	ELOSummaryID = 12;

insert	ELORank (
		ELOSummaryID
		, FloWrestlerID
		, Ranking
		)
select	ELOSummaryID = 12
		, FloWrestlerMatch.FloWrestlerID
		, Ranking = 1500
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
group by
		FloWrestlerMatch.FloWrestlerID

declare @matchid int;
declare @winnerid int;
declare @loserid int;
declare @winnerrating int;
declare @loserrating int;
declare @expectedscore decimal(9, 5);
declare @actualscore decimal(9, 5);
declare @kfactor int = 40;
declare @counter int = 0;
declare @totalmatches int = 0;
declare @sort int;

insert	#AllMatches
select	MatchSort = row_number() over (order by cast(FloMeet.StartTime as date), FloMatch.Sort)
		, MatchID = FloMatch.ID
		, WinnerID = max(case when FloWrestlerMatch.IsWinner = 1 then FloWrestlerMatch.FloWrestlerID else null end)
		, LoserID = max(case when FloWrestlerMatch.IsWinner = 0 then FloWrestlerMatch.FloWrestlerID else null end)
from	FloMeet
join	FloMatch
on		FloMeet.ID = FloMatch.FloMeetID
join	FloWrestlerMatch
on		FloMatch.ID = FloWrestlerMatch.FloMatchID
group by
		FloMatch.ID
		, cast(FloMeet.StartTime as date)
		, FloMatch.Sort
having	max(case when FloWrestlerMatch.IsWinner = 1 then 1 else 0 end) = 1
		and max(case when FloWrestlerMatch.IsWinner = 0 then 1 else 0 end) = 1;

select	@totalmatches = count(0)
from	#AllMatches;

declare matchcursor cursor for
select	MatchID
		, WinnerID
		, LoserID
		, MatchSort
from 	#AllMatches
order by
		MatchSort;

open matchcursor;

fetch next from matchcursor into @matchid, @winnerid, @loserid, @sort;

while @@fetch_status = 0
begin
	-- Get the winner wrestler current ELO rank
	select	@winnerrating = ELORank.Ranking
	from	ELORank
	where	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @winnerid;

	-- Get the loser wrestler current ELO rank
	select 	@loserrating = ELORank.Ranking
	from 	ELORank
	where 	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @loserid;

	-- Calculate the points to be won/lost
	set @expectedscore = 1 / (1 + power(10, (@loserrating - @winnerrating) / 400));
	set @actualscore = 1;

	-- Insert the match for tracking
	insert	ELOMatch (
			ELORankID
			, FloMatchID
			, IsWinner
			, RankUpdate
			, InitialELO
			, Prediction
			, Sort
			)
	select	ELORank.ID
			, @matchid
			, 1
			, @kfactor * (@actualscore - @expectedscore)
			, @winnerrating
			, 1 / (1 + power(10, (@loserrating - @winnerrating) / 400))
			, @sort
	from	ELORank
	where	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @winnerid;

	insert	ELOMatch (
			ELORankID
			, FloMatchID
			, IsWinner
			, RankUpdate
			, InitialELO
			, Prediction
			, Sort
			)
	select	ELORank.ID
			, @matchid
			, 0
			, 1 - @kfactor * (@actualscore - @expectedscore)
			, @loserrating
			, 1 / (1 + power(10, (@winnerrating - @loserrating) / 400))
			, @sort
	from	ELORank
	where	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @loserid;

	-- Update the ELO ranking
	update	ELORank
	set		Ranking = @winnerrating + @kfactor * (@actualscore - @expectedscore)
			, ModifiedDate = getdate()
	where	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @winnerid;

	update	ELORank
	set		Ranking = @loserrating - @kfactor * (@actualscore - @expectedscore)
			, ModifiedDate = getdate()
	where 	ELORank.ELOSummaryID = 12
			and ELORank.FloWrestlerID = @loserid;
	
	set @counter = @counter + 1;
	if (@counter % 100) = 0
	begin
		raiserror('%d of %d', 0, 1, @counter, @totalmatches) with nowait;
	end

	fetch next from matchcursor into @matchid, @winnerid, @loserid, @sort;
end;

close matchcursor;
deallocate matchcursor;

set nocount off;
