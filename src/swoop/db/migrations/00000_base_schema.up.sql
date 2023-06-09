CREATE SCHEMA swoop;
CREATE SCHEMA partman;
CREATE EXTENSION pg_partman SCHEMA partman;


CREATE TABLE swoop.event_state (
  name text PRIMARY KEY,
  description text NOT NULL
);

INSERT INTO swoop.event_state (name, description) VALUES
('PENDING', 'Action created and waiting to be executed'),
('QUEUED', 'Action queued for handler'),
('RUNNING', 'Action being run by handler'),
('SUCCESSFUL', 'Action successful'),
('FAILED', 'Action failed'),
('CANCELED', 'Action canceled'),
('TIMED_OUT', 'Action did not complete within allowed timeframe'),
('UNKNOWN', 'Last update was unknown state'),
('BACKOFF', 'Transient error, waiting to retry'),
(
  'INVALID',
  'Action could not be completed successfully due to '
  || 'configuration error or other incompatibility'
),
(
  'RETRIES_EXHAUSTED',
  'Call did not fail within allowed time or number of retries'
),
('INFO', 'Event is informational and does not change thread state');


CREATE TABLE swoop.payload_cache (
  payload_uuid uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  payload_hash bytea UNIQUE,
  workflow_version smallint NOT NULL,
  workflow_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  invalid_after timestamptz
);

CREATE INDEX ON swoop.payload_cache (payload_hash);


CREATE TABLE swoop.action (
  action_uuid uuid NOT NULL DEFAULT gen_random_uuid(),
  action_type text NOT NULL CHECK (action_type IN ('callback', 'workflow')),
  action_name text,
  handler_name text NOT NULL,
  parent_uuid uuid, -- reference omitted, we don't need referential integrity
  created_at timestamptz NOT NULL DEFAULT now(),
  priority smallint DEFAULT 100,
  payload_uuid uuid REFERENCES swoop.payload_cache ON DELETE RESTRICT,

  CONSTRAINT workflow_or_callback CHECK (
    CASE
      WHEN action_type = 'callback'
        THEN
          parent_uuid IS NOT NULL
          AND payload_uuid IS NULL
      WHEN action_type = 'workflow' THEN
        action_name IS NOT NULL
        AND payload_uuid IS NOT NULL
    END
  )
) PARTITION BY RANGE (created_at);

CREATE INDEX ON swoop.action (created_at);
CREATE INDEX ON swoop.action (action_uuid);
CREATE INDEX ON swoop.action (handler_name);
CREATE INDEX ON swoop.action (action_name);
CREATE TABLE swoop.action_template (LIKE swoop.action);
ALTER TABLE swoop.action_template ADD PRIMARY KEY (action_uuid);
SELECT partman.create_parent(
  'swoop.action',
  'created_at',
  'native',
  'monthly',
  p_template_table => 'swoop.action_template'
);


-- the noqa is here for GENERATED ALWAYS AS IDENTITY
-- https://github.com/sqlfluff/sqlfluff/issues/4455
CREATE TABLE swoop.thread ( -- noqa
  created_at timestamptz NOT NULL,
  last_update timestamptz NOT NULL,
  -- action_uuid reference to action omitted, we don't need referential integrity
  action_uuid uuid NOT NULL,

  -- denormalize some values off action so we
  -- don't have to join later in frequent queries
  handler_name text NOT NULL,
  priority smallint NOT NULL,

  status text NOT NULL REFERENCES swoop.event_state ON DELETE RESTRICT,
  next_attempt_after timestamptz,
  error text,

  -- We lock with advisory locks that take two int4 values, one for the table
  -- OID and one for this lock_id. Note that this sequence can recycle values,
  -- but temporal locality means recycled values should not be temporaly
  -- conincident.  Even if duplicates are "processable" at the same time, a lock
  -- ID conflict at worst causes added latency in processing, not skipped
  -- messages.
  --
  -- Recommended way to lock/unlock:
  --   swoop.lock_thread(thread.lock_id)
  --   swoop.unlock_thread(thread.lock_id)
  lock_id integer GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME swoop.thread_lock_id_seq
    MINVALUE -2147483648
    START WITH 1
    CYCLE
  )
) PARTITION BY RANGE (created_at);

CREATE INDEX ON swoop.thread (created_at);
CREATE INDEX ON swoop.thread (action_uuid);
CREATE INDEX ON swoop.thread (status);
CREATE INDEX ON swoop.thread (handler_name);
CREATE TABLE swoop.thread_template (LIKE swoop.thread);
ALTER TABLE swoop.thread_template ADD PRIMARY KEY (action_uuid);
SELECT partman.create_parent(
  'swoop.thread',
  'created_at',
  'native',
  'monthly',
  p_template_table => 'swoop.thread_template'
);


CREATE TABLE swoop.event (
  event_time timestamptz NOT NULL,
  action_uuid uuid NOT NULL, -- reference omitted, we don't need referential integrity
  status text NOT NULL,
  event_source text,
  -- max backoff cannot be more than 1 day (even that seems extreme in most cases)
  retry_seconds int CHECK (retry_seconds > 0 AND retry_seconds <= 86400),
  error text
) PARTITION BY RANGE (event_time);

CREATE INDEX ON swoop.event (event_time);
CREATE INDEX ON swoop.event (action_uuid);
CREATE TABLE swoop.event_template (LIKE swoop.event);
ALTER TABLE swoop.event_template ADD PRIMARY KEY (
  action_uuid,
  event_time,
  status
);
SELECT partman.create_parent(
  'swoop.event',
  'event_time',
  'native',
  'monthly',
  p_template_table => 'swoop.event_template'
);


CREATE TABLE swoop.input_item (
  item_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id text NOT NULL,
  collection text,
  UNIQUE NULLS NOT DISTINCT (item_id, collection)
);

CREATE TABLE swoop.item_payload (
  item_uuid uuid REFERENCES swoop.input_item ON DELETE RESTRICT,
  payload_uuid uuid REFERENCES swoop.payload_cache ON DELETE CASCADE,
  PRIMARY KEY (item_uuid, payload_uuid)
);

CREATE INDEX ON swoop.item_payload (item_uuid);


CREATE FUNCTION swoop.add_pending_event()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES
    (NEW.created_at, NEW.action_uuid, 'PENDING', 'swoop-db');
  RETURN NULL;
END;
$$;

CREATE TRIGGER add_pending_event
AFTER INSERT ON swoop.action
FOR EACH ROW EXECUTE FUNCTION swoop.add_pending_event();


CREATE FUNCTION swoop.add_thread()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  INSERT INTO swoop.thread (
    created_at,
    last_update,
    action_uuid,
    handler_name,
    priority,
    status
  ) VALUES (
    NEW.created_at,
    NEW.created_at,
    NEW.action_uuid,
    NEW.handler_name,
    NEW.priority,
    'PENDING'
  );
  RETURN NULL;
END;
$$;

CREATE TRIGGER add_thread
AFTER INSERT ON swoop.action
FOR EACH ROW EXECUTE FUNCTION swoop.add_thread();


CREATE FUNCTION swoop.update_thread()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  _latest timestamptz;
  _status text;
  _next_attempt timestamptz;
BEGIN
  SELECT last_update FROM swoop.thread WHERE action_uuid = NEW.action_uuid INTO _latest;

  -- If the event time is older than the last update we don't update the thread
  -- (we can't use a trigger condition to filter this because we don't know the
  -- last update time from the event alone).
  IF _latest IS NOT NULL AND NEW.event_time < _latest THEN
    RETURN NULL;
  END IF;

  -- Coerce status to UNKNOWN if it doesn't match a known status type
  SELECT name from swoop.event_state WHERE name = NEW.status
  UNION
  SELECT 'UNKNOWN'
  LIMIT 1
  INTO _status;

  -- If we need a next attempt time let's calculate it
  IF NEW.retry_seconds IS NOT NULL THEN
    SELECT NEW.event_time + (NEW.retry_seconds * interval '1 second') INTO _next_attempt;
  END IF;

  UPDATE swoop.thread as t SET
    last_update = NEW.event_time,
    status = _status,
    next_attempt_after = _next_attempt,
    error = NEW.error
  WHERE
    t.action_uuid = NEW.action_uuid;

  -- We _could_ try to drop the thread lock here, which would be nice for
  -- swoop-conductor so it didn't have to explicitly unlock, but the unlock
  -- function raises a warning. Being explicit isn't the worst thing either,
  -- given the complications with possible relocking and the need for clients
  -- to stay aware of that possibility.

  RETURN NULL;
END;
$$;

CREATE TRIGGER update_thread
AFTER INSERT ON swoop.event
FOR EACH ROW WHEN (NEW.status NOT IN ('PENDING', 'INFO')) -- noqa: CP02
EXECUTE FUNCTION swoop.update_thread();


CREATE FUNCTION swoop.thread_is_processable(_thread swoop.thread) -- noqa: LT01
RETURNS boolean
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  RETURN (
      _thread.status = 'PENDING'
      OR _thread.status = 'BACKOFF' AND _thread.next_attempt_after <= now()
  );
END;
$$;


CREATE FUNCTION swoop.notify_for_processable_thread()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  PERFORM
    pg_notify(handler_name, NEW.action_uuid::text)
  FROM
    swoop.action
  WHERE
    action_uuid = NEW.action_uuid;
  RETURN NULL;
END;
$$;

CREATE TRIGGER processable_notify
AFTER INSERT OR UPDATE ON swoop.thread
FOR EACH ROW WHEN (swoop.thread_is_processable(NEW)) -- noqa: CP02
EXECUTE FUNCTION swoop.notify_for_processable_thread();


-- If we are looking for processable rows we want to exclude any that already
-- have locks, as the locking mechanism doesn't prevent the same session from
-- "getting" a lock it already has.  In other words, pg_try_advisory_lock()
-- will return true multiple times when run in the same session, so cannot be
-- used effectively as a filter mechanism here.
--
-- We could do that with a CTE like this:
--
-- WITH locks AS (
--   SELECT objid AS lock_id
--   FROM pg_locks
--   WHERE
--     granted
--     AND database = (
--       SELECT oid FROM pg_database WHERE datname = current_database()
--     )
--     AND locktype = 'advisory'
--     AND classid = to_regclass('swoop.thread')::oid::integer
-- )
--
-- And then adding a `LEFT JOIN locks AS l USING (lock_id)` and a column
-- defined as `l.lock_id IS NOT NULL AS has_lock`. Then callers could filter
-- on `has_lock` before attempting to lock.
--
-- But per the pg_locks docs:
--
--   Locking the regular and/or predicate lock manager could have some impact
--   on database performance if this view is very frequently accessed. The
--   locks are held only for the minimum amount of time necessary to obtain
--   data from the lock managers, but this does not completely eliminate the
--   possibility of a performance impact.
--
--   (https://www.postgresql.org/docs/current/view-pg-locks.html)
--
-- It remains up to callers to track their locked rows by `action_uuid` and:
--   1) filter rows from this view to prevent double-locking rows
--   2) ensure locks get released when they are no longer required
--
-- Note that row-level locks--a la `FOR UPDATE SKIP LOCKED`--are not any better
-- in this regard. They _only_ support transaction-level locks, which means
-- keeping a _transaction_ open until all locked rows have been updated. This
-- also means the client cannot commit updates for the rows as they complete,
-- but instead has to hold all updates until the slowest row has finished then
-- commit the whole batch. Moreover, the lock holder will still get the locked
-- rows back if not excluding them from queries. These locks also cannot be
-- explicitly released: they persist until the end of the transaction.
--
-- In fact the only noticable advantage of the row-level locks is that they do
-- not stack, so the client doesn't have to track how many times they've
-- aquired a lock.
CREATE FUNCTION swoop.get_processable_actions(
  _ignored_action_uuids uuid [],
  _limit integer DEFAULT 10,
  _handler_names text [] DEFAULT ARRAY[]::text []
)
RETURNS TABLE (action_uuid uuid, handler_name text)
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  RETURN QUERY
  -- The CTE here is **critical**. If we don't use the CTE,
  -- then the LIMIT likely will not be applied before the
  -- WHERE clause, and we will lock rows that aren't returned.
  -- Those rows will get stuck as locked until the session
  -- drops or runs `pg_advisory_unlock_all()`.
  WITH actions AS (
    SELECT
      t.action_uuid as action_uuid,
      t.handler_name as handler_name,
      t.lock_id as lock_id
    FROM
      swoop.thread as t
    WHERE
      swoop.thread_is_processable(t) -- noqa: RF02
      AND (
        -- strangely this returns null instead of 0 if
        -- the array is empty
        array_length(_handler_names, 1) IS NULL
        OR t.handler_name = any(_handler_names)
      )
      AND (
        -- see notes on the swoop.action_thread view for
        -- the reasoning behind _ignored_action_uuids
        array_length(_ignored_action_uuids, 1) IS NULL
        OR NOT (t.action_uuid = any(_ignored_action_uuids))
      )
    ORDER BY t.priority
  )

  SELECT
    a.action_uuid AS action_uuid,
    a.handler_name AS handler_name
  FROM actions AS a
  WHERE swoop.lock_thread(a.lock_id)
  LIMIT _limit;
  RETURN;
END;
$$;


CREATE FUNCTION swoop.lock_thread(_lock_id integer)
RETURNS bool
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  RETURN (
    SELECT pg_try_advisory_lock(to_regclass('swoop.thread')::oid::integer, _lock_id)
  );
END;
$$;


CREATE FUNCTION swoop.unlock_thread(_lock_id integer)
RETURNS bool
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
BEGIN
  RETURN (
    SELECT pg_advisory_unlock(to_regclass('swoop.thread')::oid::integer, _lock_id)
  );
END;
$$;

CREATE FUNCTION swoop.check_cache(
  plhash bytea, wf_version smallint, wf_name text, invalid timestamptz
)
RETURNS record
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  rec RECORD;
BEGIN
    IF EXISTS (SELECT * FROM swoop.payload_cache WHERE payload_hash = plhash) THEN
    -- An entry exists in the cache
        DECLARE
            v_status text;
            v_job_id uuid;
            v_payload_id uuid;
        BEGIN
            SELECT t.status, t.action_uuid, p.payload_uuid
            INTO v_status, v_job_id, v_payload_id
            FROM swoop.payload_cache p
            INNER JOIN swoop.action a
            ON p.payload_uuid = a.payload_uuid
            INNER JOIN swoop.thread t
            ON a.action_uuid = t.action_uuid
            WHERE p.payload_hash = plhash
            ORDER BY t.created_at DESC
			LIMIT 1;

            IF v_status IN ('RUNNING', 'PENDING', 'QUEUED', 'BACKOFF', 'SUCCESSFUL', 'INVALID') THEN
            -- Redirect to job details for that workflow, and do not process
                SELECT FALSE, v_job_id INTO rec;
            ELSE
            -- Reprocess payload
                DECLARE
                    n_version smallint;
                    d_invalid timestamptz;
                BEGIN
                    SELECT workflow_version, invalid_after
                    INTO n_version, d_invalid
                    FROM   swoop.payload_cache
                    WHERE  payload_hash = plhash;

                    -- Check workflow version and invalidation
                    IF wf_version > n_version OR d_invalid < NOW() THEN
                        IF wf_version > n_version AND d_invalid < NOW() THEN
                            UPDATE swoop.payload_cache SET workflow_version = wf_version, invalid_after = NULL WHERE payload_hash = plhash;
                        ELSIF wf_version > n_version THEN
                            UPDATE swoop.payload_cache SET workflow_version = wf_version WHERE payload_hash = plhash;
                        ELSE
                            UPDATE swoop.payload_cache SET invalid_after = NULL WHERE payload_hash = plhash;
                        END IF;
                    END IF;
                    -- Reprocess payload with a new action_uuid
                    SELECT TRUE, v_payload_id, gen_random_uuid() INTO rec;
                END;
            END IF;
        END;
	ELSE
        -- Insert a new entry into cache table and process payload with a new action_uuid
        INSERT INTO swoop.payload_cache(payload_hash, workflow_version, workflow_name, invalid_after)
        VALUES (plhash, wf_version, wf_name, invalid)
        RETURNING TRUE, payload_uuid, gen_random_uuid() INTO rec;
	END IF;
    RETURN rec;
END;
$$;
