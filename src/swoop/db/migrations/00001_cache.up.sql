CREATE FUNCTION swoop.check_cache(plhash bytea, wf_version smallint, wf_name text, invalid timestamptz)
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
