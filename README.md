# Admin toolbox

## MySQL slow log

```shell
```

```sql
SELECT 
parseDateTime64BestEffort(timestamp, 6 ,'UTC' ) AS  timestampParsed,
* 
FROM file('slow.ndjson', 'JSONEachRow') 
WHERE 
    timestamp IS NOT NULL 
    AND timestampParsed > yesterday()
ORDER BY rows_examined DESC LIMIT 10
```
