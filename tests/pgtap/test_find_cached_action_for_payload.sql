BEGIN;
SET search_path = tap, public;
SELECT plan(7);

SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(gen_random_uuid(), 1::smallint)
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
  workflow_name
) VALUES (
  'e8d87aa6-6c42-57ed-a33c-94498fb2c20e',
  'mirror'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  workflow_name
) VALUES (
  'b262902b-b968-5cad-aabc-8f26f3d048e2',
  'mirror'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  workflow_name
) VALUES (
  'd5d64165-82df-5836-b78e-af4daee55d38',
  'cirrus'
);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  workflow_name
) VALUES (
  '737490d3-fba6-5236-af35-ec6ef9d25ec8',
  'mirror'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      'e8d87aa6-6c42-57ed-a33c-94498fb2c20e'::uuid,
      2::smallint
    )
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
  handler_type,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '0187c88d-a9e0-757e-aa36-2fbb6c834cb5',
  'workflow',
  'action_1',
  'handler_foo',
  'argo-workflow',
  null,
  '2023-04-28 15:49:00+00',
  100,
  'e8d87aa6-6c42-57ed-a33c-94498fb2c20e',
  1
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  handler_type,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
)
VALUES (
  '0187c893-2820-77b1-a7b2-f29206b702ae',
  'workflow',
  'action_2',
  'handler_foo',
  'argo-workflow',
  null,
  '2023-04-28 15:55:00+00',
  100,
  'e8d87aa6-6c42-57ed-a33c-94498fb2c20e',
  2
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  handler_type,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '0187c895-e740-7a17-9757-1d82de96c033',
  'workflow',
  'action_3',
  'handler_foo',
  'argo-workflow',
  null,
  '2023-04-28 15:58:00+00',
  100,
  'e8d87aa6-6c42-57ed-a33c-94498fb2c20e',
  3
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  handler_type,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version
) VALUES (
  '0187d2e2-9f40-7824-9392-fc2c6abc799a',
  'workflow',
  'action_1',
  'handler_foo',
  'cirrus-workflow',
  null,
  '2023-04-30 15:58:00+00',
  100,
  '737490d3-fba6-5236-af35-ec6ef9d25ec8',
  3
);


DELETE FROM swoop.thread
WHERE action_uuid = '0187d2e2-9f40-7824-9392-fc2c6abc799a';


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      '737490d3-fba6-5236-af35-ec6ef9d25ec8'::uuid,
      2::smallint
    )
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
  '0187c88d-a9e0-757e-aa36-2fbb6c834cb5',
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
  '0187c893-2820-77b1-a7b2-f29206b702ae',
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
  '0187c895-e740-7a17-9757-1d82de96c033',
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
  '0187d2e2-9f40-7824-9392-fc2c6abc799a',
  'handler_foo',
  100,
  'PENDING',
  null,
  null
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      'e8d87aa6-6c42-57ed-a33c-94498fb2c20e'::uuid,
      2::smallint
    )
  $$,
  $$
    VALUES (
      '0187c895-e740-7a17-9757-1d82de96c033'::uuid
    )
  $$,
  'return action_uuid when cache, action, thread entries exist and PENDING.'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      'e8d87aa6-6c42-57ed-a33c-94498fb2c20e'::uuid,
      3::smallint
    )
  $$,
  $$
    VALUES (
      '0187c895-e740-7a17-9757-1d82de96c033'::uuid
    )
  $$,
  'return action_uuid when cache, action, thread entries exist and SUCCESSFUL.'
);


SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      'e8d87aa6-6c42-57ed-a33c-94498fb2c20e'::uuid,
      4::smallint
    )
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
WHERE payload_uuid = 'e8d87aa6-6c42-57ed-a33c-94498fb2c20e';
UPDATE swoop.thread SET status = 'FAILED'
WHERE action_uuid = '0187c895-e740-7a17-9757-1d82de96c033';

SELECT results_eq(
  $$
    SELECT swoop.find_cached_action_for_payload(
      'e8d87aa6-6c42-57ed-a33c-94498fb2c20e'::uuid,
      3::smallint
    )
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
