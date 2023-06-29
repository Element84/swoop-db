ALTER TABLE swoop.thread
ADD COLUMN started_at timestamptz;

ALTER TABLE swoop.thread_template
ADD COLUMN started_at timestamptz;


CREATE OR REPLACE FUNCTION swoop.update_thread()
RETURNS trigger
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  _latest timestamptz;
  _next_attempt timestamptz;
  _started timestamptz;
BEGIN
  SELECT last_update, started_at FROM swoop.thread WHERE action_uuid = NEW.action_uuid
    INTO _latest, _started;

  -- If the event time is older than the last update we don't update the thread
  -- (we can't use a trigger condition to filter this because we don't know the
  -- last update time from the event alone).
  IF _latest IS NOT NULL AND NEW.event_time < _latest THEN
    IF NEW.status = 'RUNNING' THEN
        UPDATE swoop.thread as t SET started_at = NEW.event_time WHERE t.action_uuid = NEW.action_uuid;
    END IF;
    RETURN NULL;
  END IF;

  -- If we need a next attempt time let's calculate it
  IF NEW.retry_seconds IS NOT NULL THEN
    SELECT NEW.event_time + (NEW.retry_seconds * interval '1 second') INTO _next_attempt;
  END IF;

  IF _started IS NULL AND NEW.status = 'RUNNING' THEN
    SELECT  NEW.event_time INTO _started;
  END IF;

  UPDATE swoop.thread as t SET
    last_update = NEW.event_time,
    status = NEW.status,
    next_attempt_after = _next_attempt,
    error = NEW.error,
    started_at = _started
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
