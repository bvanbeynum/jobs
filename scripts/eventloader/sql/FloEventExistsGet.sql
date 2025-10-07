SELECT
    IsComplete
FROM
    Event
WHERE
    EventSystem = 'flo' AND SystemID = ?;