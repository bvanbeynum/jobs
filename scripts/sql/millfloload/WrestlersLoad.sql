set nocount on;

if object_id('tempdb..#wrestlers') is not null
	drop table #wrestlers;

create table #Wrestlers (
	WrestlerID int
	, FirstName varchar(255)
	, LastName varchar(255)
	, gRating decimal(18,9)
	, gDeviation decimal(18,9)
	, LastModified datetime
);

-- Get Flo wrestlers that've changed in the past 2 days
insert	#Wrestlers (
		WrestlerID
		, FirstName
		, LastName
		, gRating
		, gDeviation
		, LastModified
		)
select	WrestlerID = FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
		, LastModified = case when max(FloWrestler.ModifiedDate) > max(FloMatch.ModifiedDate) then max(FloWrestler.ModifiedDate) else max(FloMatch.ModifiedDate) end
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	FloMeet.IsExcluded = 0
		and FloMeet.LocationState in ('sc')
group by
		FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
having	max(FloWrestler.ModifiedDate) > getdate() - 2
		or max(FloMatch.ModifiedDate) > getdate() - 2;

-- Get Track wrestlers that've changed in the past 2 days
insert	#Wrestlers (
		WrestlerID
		, FirstName
		, LastName
		, gRating
		, gDeviation
		, LastModified
		)
select	WrestlerID = FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
		, LastModified = case when max(TrackWrestler.ModifiedDate) > max(TrackMatch.ModifiedDate) then max(TrackWrestler.ModifiedDate) else max(TrackMatch.ModifiedDate) end
from	FloWrestler
join	TrackWrestler
on		FloWrestler.FirstName + ' ' + FloWrestler.LastName = TrackWrestler.WrestlerName
join	TrackWrestlerMatch
on		TrackWrestler.ID = TrackWrestlerMatch.TrackWrestlerID
join	TrackMatch
on		TrackWrestlerMatch.TrackMatchID = TrackMatch.ID
join	TrackEvent
on		TrackMatch.TrackEventID = TrackEvent.ID
outer apply (
		select	top 1 Wrestler.WrestlerID
		from	#Wrestlers Wrestler
		where	FloWrestler.ID = Wrestler.WrestlerID
		) ExistingWrestler
where	TrackEvent.IsComplete = 1
		and TrackEvent.EventState in ('sc')
		and ExistingWrestler.WrestlerID is null
group by
		FloWrestler.ID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.gRating
		, FloWrestler.gDeviation
having	max(TrackWrestler.ModifiedDate) > getdate() - 2
		or max(TrackMatch.ModifiedDate) > getdate() - 2;

set nocount off;
