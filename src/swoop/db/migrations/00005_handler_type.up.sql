ALTER TABLE swoop.action
ADD handler_type text;

UPDATE swoop.action
SET handler_type = ''
WHERE handler_type IS NULL;

ALTER TABLE swoop.action ALTER COLUMN handler_type SET NOT NULL;

ALTER TABLE swoop.action_template ADD handler_type text NOT NULL;
