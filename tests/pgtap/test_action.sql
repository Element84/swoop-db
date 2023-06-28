BEGIN;
SET search_path = tap, public;
SELECT plan(13);

INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name,
  created_at,
  invalid_after
) VALUES (
  'cdc73916-500c-4501-a658-dd706a943d19'::uuid,
  decode('123\000456', 'escape'),
  'workflow-a',
  '2023-04-14 00:25:07.388012+00'::timestamptz,
  '2023-04-20 00:25:07.388012+00'::timestamptz
);

INSERT INTO swoop.action (
  action_uuid,
  action_type,
  handler_name,
  action_name,
  created_at,
  payload_uuid,
  workflow_version
) VALUES (
  'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid,
  'workflow',
  'argo-workflow',
  'workflow-a',
  '2023-04-13 00:25:07.388012+00'::timestamptz,
  'cdc73916-500c-4501-a658-dd706a943d19'::uuid,
  1
);

-- check event created as expected
SELECT results_eq(
  $$
    SELECT
      event_time,
      action_uuid,
      status,
      retry_seconds,
      error
    FROM
      swoop.event
    WHERE action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'
  $$,
  $$
    VALUES (
      '2023-04-13 00:25:07.388012+00'::timestamptz,
      'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid,
      'PENDING',
      null::integer,
      null
    )
  $$,
  'event should be created on action insert'
);

-- check thread created as expected
SELECT results_eq(
  $$
    SELECT
      last_update,
      action_uuid,
      status,
      next_attempt_after,
      started_at
    FROM
      swoop.thread
    WHERE
      action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'
  $$,
  $$
    VALUES (
      '2023-04-13 00:25:07.388012+00'::timestamptz,
      'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid,
      'PENDING',
      null::timestamptz,
      null::timestamptz
    )
  $$,
  'thread should be created on event insert'
);

-- get the processable action
SELECT is_empty(
  $$
    SELECT swoop.get_processable_actions(
      _ignored_action_uuids => array[]::uuid[],
      _handler_names => array['bogus']
    )
  $$,
  'should not return any processable actions - bad action name'
);

SELECT is_empty(
  $$
    SELECT swoop.get_processable_actions(
      _ignored_action_uuids => array['b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid]
    )
  $$,
  'should not return any processable actions - filtered action uuid'
);

SELECT results_eq(
  $$
    SELECT
      action_uuid,
      handler_name
    FROM
      swoop.get_processable_actions(
        _ignored_action_uuids => array[]::uuid[],
        _handler_names => array['argo-workflow']
      )
  $$,
  $$
    SELECT
      action_uuid,
      handler_name
    FROM
      swoop.action
    WHERE
      action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'
  $$,
  'should get our processable action'
);

-- check locks
SELECT results_eq(
  $$
    SELECT
      classid,
      objid
    FROM
      pg_locks
    WHERE
      locktype = 'advisory'
  $$,
  $$
    SELECT
      to_regclass('swoop.thread')::oid,
      lock_id::oid
    FROM
      swoop.thread
    WHERE
      action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'
  $$,
  'should have an advisory lock for the processable action we grabbed'
);

-- insert backoff event for action, drop lock,
-- check thread update, and check processable
INSERT INTO swoop.event (
  event_time,
  action_uuid,
  status,
  retry_seconds,
  error
) VALUES (
  '2023-04-13 00:25:08.388012+00'::timestamptz,
  'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid,
  'BACKOFF',
  1,
  'some error string'
);

SELECT
  ok(
    swoop.unlock_thread(lock_id),
    'should release the lock on our row'
  )
FROM swoop.thread
WHERE
  action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid;

SELECT is_empty(
  $$
    SELECT
      classid,
      objid
    FROM
      pg_locks
    WHERE
      locktype = 'advisory'
  $$,
  'should not have any advisory locks'
);

SELECT
  matches(
    status,
    'BACKOFF',
    'thread status should be backoff'
  ) AS matches
FROM swoop.thread;

SELECT
  cmp_ok(
    next_attempt_after,
    '=',
    last_update + interval '1 second',
    'thread next attempt should be last update plus backoff time'
  ) AS cmp
FROM swoop.thread;

SELECT results_eq(
  $$
    SELECT
      action_uuid,
      handler_name
    FROM
      swoop.get_processable_actions(
        _ignored_action_uuids => array[]::uuid[],
        _handler_names => array['argo-workflow']
      )
  $$,
  $$
    SELECT action_uuid, handler_name
    FROM swoop.action
  $$,
  'should get our processable action in the backoff state'
);

-- insert queued event, drop lock, and check it is not processable
INSERT INTO swoop.event (
  event_time,
  action_uuid,
  status
) VALUES (
  '2023-04-13 00:25:10.388012+00'::timestamptz,
  'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid,
  'QUEUED'
);

SELECT
  ok(
    swoop.unlock_thread(lock_id),
    'should release the lock on our row once more'
  )
FROM swoop.thread
WHERE
  action_uuid = 'b15120b8-b7ab-4180-9b7a-b0384758f468'::uuid;


SELECT is_empty(
  $$
    SELECT swoop.get_processable_actions(
      _ignored_action_uuids => array[]::uuid[]
    )
  $$,
  'should not return any processable actions due to state'
);


SELECT * FROM finish(); -- noqa
ROLLBACK;
