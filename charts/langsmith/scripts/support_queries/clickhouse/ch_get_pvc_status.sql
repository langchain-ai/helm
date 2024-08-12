-- This query checks the amount of free disk space on the 
-- volume(s) dedicated to Clickhouse.

select 
    hostname(), 
    free_space,
    total_space,
    round(100.0*free_space/total_space,1) as pct_free 
from clusterAllReplicas(default,system.disks)
where path is not null
and type != 'ObjectStorage'
