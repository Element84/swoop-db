DROP FUNCTION swoop.check_cache;

DELETE FROM schema_version WHERE version = ${version (where)||1||Integer||where nullable unformatted ds=11 dt=INTEGER}$;
