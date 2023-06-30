BEGIN;
SET search_path = tap, public;
SELECT plan(4);

SELECT isa_ok(gen_uuid_v7(now()), 'uuid', 'gen_uuid_v7 should return a uuid');

SELECT alike(
  gen_uuid_v7('2020-07-08 19:19:19+00'::timestamptz)::text,
  '01732fde-36d8-7%',
  'Expecting the timestamp portion should be consistent'
);

SELECT is(
  timestamp_from_uuid_v7(
    gen_uuid_v7('2020-07-08 19:19:19.33365+00'::timestamptz)
  ),
  '2020-07-08 19:19:19.333+00'::timestamptz,
  'should be able to reverse the uuid back into the input timestamp'
);

PREPARE thrower AS SELECT timestamp_from_uuid_v7(gen_random_uuid()); -- noqa: PRS
SELECT throws_ok(
  'thrower',
  'P0001',
  'UUID must be version 7, not 4',
  'should throw an error if trying to get a timestamp from a non-v7 uuid'
);

SELECT * FROM finish(); -- noqa
ROLLBACK;
