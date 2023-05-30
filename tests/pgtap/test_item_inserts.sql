-- noqa: disable=ST03
BEGIN;
SET search_path = tap, public;
SELECT plan(5);

WITH ins AS (
  INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
    'f5db7f4d-7a72-441c-a9e5-ec2d88c66f5c',
    'id1',
    'collection1'
  )
  ON CONFLICT DO NOTHING
  RETURNING true
)

SELECT ok(exists(table ins), 'inserting should succeed');

WITH ins AS (
  INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
    'f5db7f4d-7a72-441c-a9e5-ec2d88c66f5c',
    'id1',
    'collection1'
  )
  ON CONFLICT DO NOTHING
  RETURNING true
)

SELECT ok(NOT exists(table ins), 'a duplicate should fail');

WITH ins AS (
  INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
    '01887754-5a7c-430f-abc7-3b4ac0b1281d',
    'id3',
    null
  )
  ON CONFLICT DO NOTHING
  RETURNING true
)

SELECT ok(
  exists(table ins),
  'inserting with a null collection should be allowed'
);

WITH ins AS (
  INSERT INTO swoop.input_item (item_id, collection) VALUES (
    'id4',
    null
  )
  ON CONFLICT DO NOTHING
  RETURNING true
)

SELECT ok(
  exists(table ins),
  'and we should be able to do that again with a differnt uuid'
);

WITH ins AS (
  INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
    '01887754-5a7c-430f-abc7-3b4ac0b1281d',
    'id3',
    null
  )
  ON CONFLICT DO NOTHING
  RETURNING true
)

SELECT ok(NOT exists(table ins), 'but again a duplicate should fail');

SELECT * FROM finish(); -- noqa
ROLLBACK;
