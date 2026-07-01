select	WinnerID
		, LoserID
		, WinType
		, Division
from	(
		select	WinnerID = Winner.EventWrestlerID
				, LoserID = Loser.EventWrestlerID
				, EventMatch.WinType
				, Division = case 
					when EventMatch.Division like '%girl%' then 'Girls'
					when EventMatch.Division like '%ms%' or EventMatch.Division like '%middle%' then 'MS'
					when EventMatch.Division in ('10U', '8U', '12U', '14U') then 'MS'
					when EventMatch.Division in ('tot', 'bantam', 'midget', '6U', 'elem') then 'Youth'
					when EventMatch.Division like '%under%' then 'Youth'
					when EventMatch.Division like 'jv%' or EventMatch.Division like '%junior%' then 'JV'
					when EventMatch.Division like '%varsity%' then 'HS'
					when EventMatch.Division like 'hs%' then 'HS'
					when EventMatch.Division like '%high%' then 'HS'
					when Event.EventName like '%girl%' then 'Girls'
					when Event.EventName like '%women%' then 'Girls'
					when Event.EventName like '%woman%' then 'Girls'
					when Event.EventName like '% middle%' then 'MS'
					when Event.EventName like '% ms %' then 'MS'
					when Event.EventName like '%/ms %' then 'MS'
					when Event.EventName like '% ms/%' then 'MS'
					when Event.EventName like '% jv %' then 'JV'
					when Event.EventName like '% jv/%' then 'JV'
					when Event.EventName like '%/jv%' then 'JV'
					when Event.EventName like '% jv%' then 'JV'
					when Event.EventName like 'jv %' then 'JV'
					when nullif(trim(EventMatch.Division), '') is not null then EventMatch.Division
					else 'HS'
					end
		from	EventWrestlerMatch
		join	EventWrestlerMatch as Winner
		on		EventWrestlerMatch.EventMatchID = Winner.EventMatchID
				and Winner.IsWinner = 1
		join	EventWrestlerMatch as Loser
		on		EventWrestlerMatch.EventMatchID = Loser.EventMatchID
				and Loser.IsWinner = 0
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		where	Event.EventDate between ? and ?
				and EventMatch.WinType not in ('bye', 'for', 'nc')
		) as DivisionMapping;
