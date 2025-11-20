SELECT
	IsComplete
	, IsExcluded
FROM
	Event
WHERE
	EventSystem = 'flo' AND SystemID = ?;