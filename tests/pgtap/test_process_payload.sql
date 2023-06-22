BEGIN;
SET search_path = tap, public;
SELECT plan(7);

SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash_test', 'utf-8'), 1::smallint)
  $$,
  $$
    VALUES (
      null::uuid
    )
  $$,
  'return null for payload that does not have a cache entry'
);


INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name
) VALUES (
  'e8d87aa6-6c42-47ed-a33c-94498fb2c20e',
  convert_to('hash1', 'utf-8'),
  'mirror'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name
) VALUES (
  'b262902b-b968-4cad-aabc-8f26f3d048e2',
  convert_to('hash2', 'utf-8'),
  'mirror'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name
) VALUES (
  'd5d64165-82df-4836-b78e-af4daee55d38',
  convert_to('hash3', 'utf-8'),
  'cirrus'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name
) VALUES (
  '737490d3-fba6-4236-af35-ec6ef9d25ec8',
  convert_to('hash4', 'utf-8'),
  'mirror'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash1', 'utf-8'), 2::smallint)
  $$,
  $$
    VALUES (
      null::uuid
    )
  $$,
  'return null for payload that has cache but no action entry.'
);


INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '2595f2da-81a6-423c-84db-935e6791046e',
  'workflow',
  'action_1',
  'handler_foo',
  'cf8ff7f0-ce5d-4de6-8026-4e551787385f',
  '2023-04-28 15:49:00+00',
  100,
  'e8d87aa6-6c42-47ed-a33c-94498fb2c20e',
  1
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
)
VALUES (
  '71ba4b00-245e-4189-9ee8-0016a3ac274d',
  'workflow',
  'action_2',
  'handler_foo',
  '04001ac8-2cae-4536-8ae7-bf0c55897594',
  '2023-04-28 15:55:00+00',
  100,
  'e8d87aa6-6c42-47ed-a33c-94498fb2c20e',
  2
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '81842304-0aa9-4609-89f0-1c86819b0752',
  'workflow',
  'action_3',
  'handler_foo',
  'c11e2bb6-4e22-427c-bc05-e709c98bbf41',
  '2023-04-28 15:58:00+00',
  100,
  'e8d87aa6-6c42-47ed-a33c-94498fb2c20e',
  3
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '7716319b-5064-41fc-be04-0e1330c0c290',
  'workflow',
  'action_1',
  'handler_foo',
  '8606e6d4-0f43-43d3-be7a-6966869a4735',
  '2023-04-30 15:58:00+00',
  100,
  '737490d3-fba6-4236-af35-ec6ef9d25ec8',
  3
);


DELETE FROM swoop.thread
WHERE action_uuid = '7716319b-5064-41fc-be04-0e1330c0c290';


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash4', 'utf-8'), 2::smallint)
  $$,
  $$
    VALUES (
      null::uuid
    )
  $$,
  'return null for payload that has cache and action entry but no thread'
);


INSERT INTO swoop.thread (
  created_at,
  last_update,
  action_uuid,
  handler_name,
  priority,
  status,
  next_attempt_after,
  error
) VALUES (
  '2023-04-28 15:49:00+00',
  '2023-04-28 15:49:00+00',
  '2595f2da-81a6-423c-84db-935e6791046e',
  'handler_foo',
  100,
  'PENDING',
  null,
  null
);

INSERT INTO swoop.thread (
  created_at,
  last_update,
  action_uuid,
  handler_name,
  priority,
  status,
  next_attempt_after,
  error
) VALUES (
  '2023-04-28 15:55:00+00',
  '2023-04-28 15:55:00+00',
  '71ba4b00-245e-4189-9ee8-0016a3ac274d',
  'handler_foo',
  100,
  'PENDING',
  null,
  null
);

INSERT INTO swoop.thread (
  created_at,
  last_update,
  action_uuid,
  handler_name,
  priority,
  status,
  next_attempt_after,
  error
) VALUES (
  '2023-04-28 15:58:00+00',
  '2023-04-28 15:58:00+00',
  '81842304-0aa9-4609-89f0-1c86819b0752',
  'handler_foo',
  100,
  'SUCCESSFUL',
  null,
  null
);

INSERT INTO swoop.thread (
  created_at,
  last_update,
  action_uuid,
  handler_name,
  priority,
  status,
  next_attempt_after,
  error
) VALUES (
  '2023-04-30 15:58:00+00',
  '2023-04-30 15:58:00+00',
  '7716319b-5064-41fc-be04-0e1330c0c290',
  'handler_foo',
  100,
  'PENDING',
  null,
  null
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash1', 'utf-8'), 2::smallint)
  $$,
  $$
    VALUES (
      '81842304-0aa9-4609-89f0-1c86819b0752'::uuid
    )
  $$,
  'return action_uuid when cache, action, thread entries exist and PENDING.'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash1', 'utf-8'), 3::smallint)
  $$,
  $$
    VALUES (
      '81842304-0aa9-4609-89f0-1c86819b0752'::uuid
    )
  $$,
  'return action_uuid when cache, action, thread entries exist and SUCCESSFUL.'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash1', 'utf-8'), 4::smallint)
  $$,
  $$
    VALUES (
      null::uuid
    )
  $$,
  'return null when workflow_version is greater than what is in database.'
);


/* Set invalid_after to an arbitrary date in the past for
 a payload_uuid, and set the corresponding thread for the action
associated with that payload_uuid to a FAILED state
*/

UPDATE swoop.payload_cache SET invalid_after = '2000-01-01 00:00:00+00'
WHERE payload_uuid = 'e8d87aa6-6c42-47ed-a33c-94498fb2c20e';
UPDATE swoop.thread SET status = 'FAILED'
WHERE action_uuid = '81842304-0aa9-4609-89f0-1c86819b0752';

SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(convert_to('hash1', 'utf-8'), 3::smallint)
  $$,
  $$
    VALUES (
      null::uuid
    )
  $$,
  'return null when invalid_after is not null and greater than current date.'
);


SELECT * FROM finish(); -- noqa
ROLLBACK;
