-- gen_uuid_v7() modified from
-- https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74
--
-- Original license:
--
-- Copyright 2023 Kyle Hubert <kjmph@users.noreply.github.com>
-- (https://github.com/kjmph)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the “Software”), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
CREATE OR REPLACE FUNCTION public.gen_uuid_v7(_timestamp timestamptz)
RETURNS uuid
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  _unix_ts_ms bytea;
  _uuid_bytes bytea;
BEGIN
  _unix_ts_ms = substring(
    int8send(floor(extract(epoch from _timestamp) * 1000)::bigint) from 3
  );

  -- use random v4 uuid as starting point (which has the same variant we need)
  _uuid_bytes = uuid_send(gen_random_uuid());

  -- overlay timestamp
  _uuid_bytes = overlay(_uuid_bytes PLACING _unix_ts_ms FROM 1 FOR 6);

  -- set version 7
  _uuid_bytes = set_byte(
    _uuid_bytes,
    6,
    (b'0111' || get_byte(_uuid_bytes, 6)::bit(4))::bit(8)::int
  );

  RETURN encode(_uuid_bytes, 'hex')::uuid;
END;
$$;


CREATE OR REPLACE FUNCTION public.uuid_version(_uuid_bytes bytea)
RETURNS integer
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
AS $$
  SELECT get_byte(_uuid_bytes, 6)::bit(8)::bit(4)::int;
$$;


CREATE OR REPLACE FUNCTION public.uuid_version(_uuid uuid)
RETURNS integer
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
AS $$
  SELECT uuid_version(uuid_send(_uuid));
$$;


CREATE OR REPLACE FUNCTION public.timestamp_from_uuid_v7(_uuid uuid)
RETURNS timestamptz
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
AS $$
DECLARE
  _uuid_version integer;
  _uuid_bytes bytea;
BEGIN
  SELECT uuid_send(_uuid) INTO _uuid_bytes;
  SELECT uuid_version(_uuid_bytes) INTO _uuid_version;

  IF _uuid_version != 7 THEN
    RAISE EXCEPTION 'UUID must be version 7, not %', _uuid_version
      USING HINT = 'You can only call this function with a UUID v7 input';
  END IF;

  RETURN to_timestamp(('x0000' || encode(
    substring(_uuid_bytes FOR 4) || substring(_uuid_bytes FROM 5 FOR 2),
    'hex'
  ))::bit(64)::bigint::numeric / 1000);
END;
$$;


DROP FUNCTION swoop.find_cached_action_for_payload;
CREATE OR REPLACE FUNCTION swoop.find_cached_action_for_payload(
  _payload_uuid uuid,
  _wf_version smallint
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
  v_status text;
  n_version smallint;
  d_invalid timestamptz;
  v_action_id uuid;
BEGIN
  SELECT t.status, a.workflow_version, p.invalid_after, a.action_uuid
  INTO v_status, n_version, d_invalid, v_action_id
  FROM swoop.payload_cache p
  INNER JOIN swoop.action a
  USING (payload_uuid)
  INNER JOIN swoop.thread t
  USING (action_uuid)
  WHERE p.payload_uuid = _payload_uuid
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_status IN ('RUNNING', 'PENDING', 'QUEUED', 'BACKOFF') THEN
  -- Redirect to job details for that workflow, and do not process
    RETURN v_action_id;
  ELSIF _wf_version > n_version THEN
    RETURN null;
  ELSIF d_invalid IS NOT NULL and d_invalid < now() THEN
    RETURN null;
  ELSIF v_status IN ('SUCCESSFUL', 'INVALID') THEN
    RETURN v_action_id;
  ELSE
    RETURN null;
  END IF;
END;
$$;


-- Note that we have no possible forward migration for payload_cache
-- entries to update them from v4 to v5 uuids. To do so would require
-- the string input from which the payload_hash was generated.
--
-- At this stage of development, the pragmatic choice is to break
-- backward compatibility and truncate all tables.
TRUNCATE swoop.payload_cache CASCADE;
TRUNCATE swoop.thread;
TRUNCATE swoop.event;

ALTER TABLE swoop.action
ALTER COLUMN action_uuid
SET DEFAULT gen_uuid_v7(now());
ALTER TABLE swoop.action
ADD CONSTRAINT uuid_timestamp_matches_created_at CHECK (
  timestamp_from_uuid_v7(action_uuid) = date_trunc('ms', created_at)
);

ALTER TABLE swoop.payload_cache ALTER COLUMN payload_uuid DROP DEFAULT;
ALTER TABLE swoop.payload_cache DROP COLUMN payload_hash;
ALTER TABLE swoop.payload_cache
ADD CONSTRAINT payload_cache_payload_uuid_check CHECK (
  uuid_version(payload_uuid) = 5
);
