-- payloads
INSERT INTO swoop.payload_cache (
  payload_uuid,
  payload_hash,
  workflow_name,
  created_at
) VALUES (
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77',
  decode('PsqWxdKjAjrV1+BueXnAS1cWIhU=', 'base64'),
  'some_workflow',
  '2023-04-28 15:49:00+00'
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
  payload_uuid,
  workflow_version,
  handler_type
) VALUES (
  '2595f2da-81a6-423c-84db-935e6791046e',
  'workflow',
  'action_1',
  'handler_foo',
  null,
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77',
  1,
  'argo-workflow'
);
INSERT INTO swoop.action (
  action_uuid,
  action_type,
  action_name,
  handler_name,
  parent_uuid,
  created_at,
  priority,
  payload_uuid,
  workflow_version,
  handler_type
) VALUES (
  '81842304-0aa9-4609-89f0-1c86819b0752',
  'workflow',
  'action_2',
  'handler_foo',
  null,
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-472e-9f36-7242cc2aca77',
  1,
  'cirrus-workflow'
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
