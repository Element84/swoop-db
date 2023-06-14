-- Move column workflow_version

ALTER TABLE swoop.action
ADD workflow_version smallint NOT NULL;

ALTER TABLE swoop.action_template ADD workflow_version smallint NOT NULL;


ALTER TABLE swoop.payload_cache
DROP COLUMN workflow_version;
