-- items
INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
  'f5db7f4d-7a72-441c-a9e5-ec2d88c66f5c',
  'id1',
  'collection1'
);
INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
  'a9b95ee3-3fee-4e02-8565-8137b2d036ed',
  'id2',
  'collection1'
);
INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
  '01887754-5a7c-430f-abc7-3b4ac0b1281d',
  'id3',
  NULL
);
INSERT INTO swoop.input_item (item_uuid, item_id, collection) VALUES (
  'dc87a668-66ae-4ac6-86f1-afc8e467d9e7',
  'id4',
  NULL
);

-- payloads
INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_version,
  workflow_name,
  created_at
) VALUES (
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77',
  decode('PsqWxdKjAjrV1+BueXnAS1cWIhU=', 'base64'),
  1,
  'some_workflow',
  '2023-04-28 15:49:00+00'
);

-- item - payload relations
INSERT INTO swoop.item_payload (item_uuid, payload_uuid) VALUES (
  'f5db7f4d-7a72-441c-a9e5-ec2d88c66f5c',
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77'
);
INSERT INTO swoop.item_payload (item_uuid, payload_uuid) VALUES (
  '01887754-5a7c-430f-abc7-3b4ac0b1281d',
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77'
);

-- actions
INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid
) VALUES (
  '2595f2da-81a6-423c-84db-935e6791046e',
  'workflow',
  'action_1',
  'handler_foo',
  'cf8ff7f0-ce5d-4de6-8026-4e551787385f',
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77'
);
INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid
) VALUES (
  '81842304-0aa9-4609-89f0-1c86819b0752',
  'workflow',
  'action_2',
  'handler_foo',
  '2595f2da-81a6-423c-84db-935e6791046e',
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77'
);

-- threads
--   created by action insert trigger

-- events
--     PENDING events created by action insert trigger
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:01+00',
  '2595f2da-81a6-423c-84db-935e6791046e',
  'QUEUED',
  'swoop-db'
);
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:02+00',
  '2595f2da-81a6-423c-84db-935e6791046e',
  'RUNNING',
  'swoop-db'
);
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:03+00',
  '2595f2da-81a6-423c-84db-935e6791046e',
  'SUCCESSFUL',
  'swoop-db'
);
