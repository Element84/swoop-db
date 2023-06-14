-- Move column workflow_version

ALTER TABLE swoop.action
DROP COLUMN workflow_version;

ALTER TABLE swoop.payload_cache
ADD workflow_version smallint NOT NULL;
