DELETE FROM swoop.event_state WHERE name = 'UNKNOWN';


CREATE OR REPLACE FUNCTION swoop.update_thread()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  _latest timestamptz;
  _next_attempt timestamptz;
BEGIN
  SELECT last_update FROM swoop.thread WHERE action_uuid = NEW.action_uuid INTO _latest;

  -- If the event time is older than the last update we don't update the thread
  -- (we can't use a trigger condition to filter this because we don't know the
  -- last update time from the event alone).
  IF _latest IS NOT NULL AND NEW.event_time < _latest THEN
    RETURN NULL;
  END IF;

  -- If we need a next attempt time let's calculate it
  IF NEW.retry_seconds IS NOT NULL THEN
    SELECT NEW.event_time + (NEW.retry_seconds * interval '1 second') INTO _next_attempt;
  END IF;

  UPDATE swoop.thread as t SET
    last_update = NEW.event_time,
    status = NEW.status,
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


-- Update check_cache function

DROP FUNCTION IF EXISTS swoop.check_cache;

CREATE FUNCTION swoop.check_cache(plhash bytea)
RETURNS RECORD
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
            SELECT t.status
            INTO v_status
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
                SELECT FALSE INTO rec;
            ELSE
                -- Reprocess payload
                SELECT TRUE INTO rec;
            END IF;
        END;
	ELSE
        SELECT TRUE INTO rec;
	END IF;
    RETURN rec;
END;
$$;