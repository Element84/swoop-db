CREATE TABLE swoop.input_item (
  item_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id text NOT NULL,
  collection text,
  UNIQUE NULLS NOT DISTINCT (item_id, collection)
);

CREATE TABLE swoop.item_payload (
  item_uuid uuid REFERENCES swoop.input_item ON DELETE RESTRICT,
  payload_uuid uuid REFERENCES swoop.payload_cache ON DELETE CASCADE,
  PRIMARY KEY (item_uuid, payload_uuid)
);

CREATE INDEX ON swoop.item_payload (item_uuid);
