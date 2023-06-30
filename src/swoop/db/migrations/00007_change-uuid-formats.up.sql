-- gen_uuid_v7() from https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74
--
-- License:
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
END
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
  SELECT get_byte( _uuid_bytes, 6)::bit(8)::bit(4)::int INTO _uuid_version;

  IF _uuid_version != 7 THEN
    RAISE EXCEPTION 'UUID must be version 7, not %', _uuid_version
      USING HINT = 'You can only call this function with a UUID v7 input';
  END IF;

  RETURN to_timestamp(('x0000' || encode(
    substring(_uuid_bytes FOR 4) || substring(_uuid_bytes FROM 5 FOR 2),
    'hex'
  ))::bit(64)::bigint::numeric / 1000);
END
$$;


ALTER TABLE swoop.action ADD COLUMN _tmp_uuid uuid;
UPDATE swoop.action SET _tmp_uuid = gen_uuid_v7(created_at);

UPDATE swoop.event AS e
SET action_uuid = a._tmp_uuid
FROM swoop.action AS a
WHERE e.action_uuid = a.action_uuid;

UPDATE swoop.thread AS t
SET action_uuid = a._tmp_uuid
FROM swoop.action AS a
WHERE t.action_uuid = a.action_uuid;

UPDATE swoop.action SET action_uuid = _tmp_uuid;
ALTER TABLE swoop.action DROP COLUMN _tmp_uuid;
ALTER TABLE swoop.action
ALTER COLUMN action_uuid
SET DEFAULT gen_uuid_v7(now());
ALTER TABLE swoop.action
ADD CONSTRAINT uuid_timestamp_matches_created_at CHECK (
  timestamp_from_uuid_v7(action_uuid) = date_trunc('ms', created_at)
);
