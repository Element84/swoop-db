# Making new migration tests

Copy the fixture pre-migration to this dir as
`<start_migration_id>_base_01.sql`.

Then to generate the result file:

```shell
swoop-db drop
swoop-db create
swoop-db migrate --target <start_migration_id>
swoop-db execute-sql < tests/fixtures/migrations/<start_migration_id>_base_01.sql
pg_dump \
    -d swoop \
    -U postgres \
    --inserts \
    --data-only \
    --exclude-table swoop.schema_version \
    | grep -ve '^--' -ve '^$' \
    > tests/fixtures/migrations/<end_migration_id>_result.sql
```
