select	IsRefresh = case when coalesce(max(LastUpdate), getdate() - 365) < getdate() - 1 then 1 else 0 end
from	FloUpdate;