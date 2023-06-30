-- payloads
INSERT INTO swoop.payload_cache (
  payload_uuid,
  workflow_name,
  created_at
) VALUES (
  'ade69fe7-1d7d-572e-9f36-7242cc2aca77',
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
  '0187c88d-a9e0-788c-adcb-c0b951f8be91',
  'workflow',
  'action_1',
  'handler_foo',
  null,
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-572e-9f36-7242cc2aca77',
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
  '0187c88d-a9e0-757e-aa36-2fbb6c834cb5',
  'workflow',
  'action_2',
  'handler_foo',
  null,
  '2023-04-28 15:49:00+00',
  100,
  'ade69fe7-1d7d-572e-9f36-7242cc2aca77',
  1,
  'cirrus-workflow'
);

-- threads
--   created by action insert trigger

-- events
--     PENDING events created by action insert trigger
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:01+00',
  '0187c88d-a9e0-788c-adcb-c0b951f8be91',
  'QUEUED',
  'swoop-db'
);
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:02+00',
  '0187c88d-a9e0-788c-adcb-c0b951f8be91',
  'RUNNING',
  'swoop-db'
);
INSERT INTO swoop.event (event_time, action_uuid, status, event_source) VALUES (
  '2023-04-28 15:49:03+00',
  '0187c88d-a9e0-788c-adcb-c0b951f8be91',
  'SUCCESSFUL',
  'swoop-db'
);
