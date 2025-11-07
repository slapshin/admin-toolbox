# Admin toolbox

## MySQL slow log analyzing

```shell
# start clickhouse
make up
# convert slow log to NDJSON
./mysql_slowlog_to_json.py tmp/slow.log -o tmp/slow.ndjson
```

queries example:

```sql
SELECT 
parseDateTime64BestEffort(timestamp, 6 ,'UTC' ) AS timestampParsed,
* 
FROM file('slow.ndjson', 'JSONEachRow') 
WHERE 
    timestamp IS NOT NULL 
    AND timestampParsed > yesterday()
ORDER BY rows_examined DESC LIMIT 10
```
