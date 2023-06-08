INSERT INTO swoop.schema_version VALUES(1);

CREATE FUNCTION swoop.check_cache(plhash bytea, wf_version smallint, wf_name text, invalid timestamptz)
RETURNS RECORD
AS $$
DECLARE
  rec RECORD;
BEGIN
    IF EXISTS (SELECT * FROM swoop.payload_cache WHERE payload_hash = plhash) THEN
    -- cache already exists
        DECLARE
            _status text;
            _jobid uuid;
            _payloadid uuid;
        BEGIN
            SELECT t.status, t.action_uuid, p.payload_uuid
            INTO _status,_jobid, _payloadid
            FROM swoop.payload_cache p
            INNER JOIN swoop.action a
            ON p.payload_uuid = a.payload_uuid
            INNER JOIN swoop.thread t
            ON a.action_uuid = t.action_uuid
            WHERE p.payload_hash = plhash
            ORDER BY t.created_at DESC
			LIMIT 1;

            IF _status IN ('RUNNING', 'PENDING', 'QUEUED', 'BACKOFF', 'SUCCESSFUL', 'INVALID') THEN
            -- redirect to job details for that workflow, do not process
                SELECT FALSE, _jobid INTO rec;
            ELSE
            --     -- this means there is already a record in both payload_cache and action tables for this
            --     -- need to reprocess
                DECLARE
                    _ver smallint;
                    _invalid timestamptz;
                BEGIN
                    SELECT workflow_version, invalid_after
                    INTO _ver, _invalid
                    FROM   swoop.payload_cache
                    WHERE  payload_hash = plhash;

                    IF wf_version > _ver OR _invalid < NOW() THEN
                        IF wf_version > _ver AND _invalid < NOW() THEN
                            UPDATE swoop.payload_cache SET workflow_version = wf_version, invalid_after = NULL WHERE payload_hash = plhash;
                        ELSIF wf_version > _ver THEN
                            UPDATE swoop.payload_cache SET workflow_version = wf_version WHERE payload_hash = plhash;
                        ELSE
                            UPDATE swoop.payload_cache SET invalid_after = NULL WHERE payload_hash = plhash;
                        END IF;

                        -- reprocess the payload
                        SELECT TRUE, _payloadid, gen_random_uuid() INTO rec;
                    ELSE
                        SELECT FALSE, _jobid INTO rec;
                    END IF;
                END;
            END IF;
        END;
	ELSE
        INSERT INTO swoop.payload_cache(payload_hash, workflow_version, workflow_name, invalid_after)
        VALUES (plhash, wf_version, wf_name, invalid)
        RETURNING TRUE, payload_uuid, gen_random_uuid() INTO rec;
    -- process the payload
	END IF;
    RETURN rec;
END;
$$
LANGUAGE plpgsql;
