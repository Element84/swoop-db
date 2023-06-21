-- Move column workflow_version

ALTER TABLE swoop.action
ADD workflow_version smallint;

UPDATE swoop.action
SET workflow_version = -1
WHERE workflow_version IS NULL;

ALTER TABLE swoop.action ALTER COLUMN workflow_version SET NOT NULL;

ALTER TABLE swoop.action_template ADD workflow_version smallint NOT NULL;


ALTER TABLE swoop.payload_cache
DROP COLUMN workflow_version;
