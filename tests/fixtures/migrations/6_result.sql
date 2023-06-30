SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
INSERT INTO partman.part_config VALUES ('swoop.action', 'created_at', 'native', '1 mon', NULL, 4, 4, 30, 'none', true, NULL, NULL, true, true, false, 'YYYY_MM', 'on', true, false, false, false, '', true, 'swoop.action_template', NULL, false, true, NULL, false, false);
INSERT INTO partman.part_config VALUES ('swoop.thread', 'created_at', 'native', '1 mon', NULL, 4, 4, 30, 'none', true, NULL, NULL, true, true, false, 'YYYY_MM', 'on', true, false, false, false, '', true, 'swoop.thread_template', NULL, false, true, NULL, false, false);
INSERT INTO partman.part_config VALUES ('swoop.event', 'event_time', 'native', '1 mon', NULL, 4, 4, 30, 'none', true, NULL, NULL, true, true, false, 'YYYY_MM', 'on', true, false, false, false, '', true, 'swoop.event_template', NULL, false, true, NULL, false, false);
INSERT INTO swoop.action_p2023_04 VALUES ('2595f2da-81a6-423c-84db-935e6791046e', 'workflow', 'action_1', 'handler_foo', NULL, '2023-04-28 15:49:00+00', 100, 'ade69fe7-1d7d-472e-9f36-7242cc2aca77', 1, '');
INSERT INTO swoop.action_p2023_04 VALUES ('81842304-0aa9-4609-89f0-1c86819b0752', 'workflow', 'action_2', 'handler_foo', NULL, '2023-04-28 15:49:00+00', 100, 'ade69fe7-1d7d-472e-9f36-7242cc2aca77', 1, '');
INSERT INTO swoop.event_p2023_04 VALUES ('2023-04-28 15:49:00+00', '2595f2da-81a6-423c-84db-935e6791046e', 'PENDING', 'swoop-db', NULL, NULL);
INSERT INTO swoop.event_p2023_04 VALUES ('2023-04-28 15:49:00+00', '81842304-0aa9-4609-89f0-1c86819b0752', 'PENDING', 'swoop-db', NULL, NULL);
INSERT INTO swoop.event_p2023_04 VALUES ('2023-04-28 15:49:01+00', '2595f2da-81a6-423c-84db-935e6791046e', 'QUEUED', 'swoop-db', NULL, NULL);
INSERT INTO swoop.event_p2023_04 VALUES ('2023-04-28 15:49:02+00', '2595f2da-81a6-423c-84db-935e6791046e', 'RUNNING', 'swoop-db', NULL, NULL);
INSERT INTO swoop.event_p2023_04 VALUES ('2023-04-28 15:49:03+00', '2595f2da-81a6-423c-84db-935e6791046e', 'SUCCESSFUL', 'swoop-db', NULL, NULL);
INSERT INTO swoop.event_state VALUES ('PENDING', 'Action created and waiting to be executed');
INSERT INTO swoop.event_state VALUES ('QUEUED', 'Action queued for handler');
INSERT INTO swoop.event_state VALUES ('RUNNING', 'Action being run by handler');
INSERT INTO swoop.event_state VALUES ('SUCCESSFUL', 'Action successful');
INSERT INTO swoop.event_state VALUES ('FAILED', 'Action failed');
INSERT INTO swoop.event_state VALUES ('CANCELED', 'Action canceled');
INSERT INTO swoop.event_state VALUES ('TIMED_OUT', 'Action did not complete within allowed timeframe');
INSERT INTO swoop.event_state VALUES ('BACKOFF', 'Transient error, waiting to retry');
INSERT INTO swoop.event_state VALUES ('INVALID', 'Action could not be completed successfully due to configuration error or other incompatibility');
INSERT INTO swoop.event_state VALUES ('RETRIES_EXHAUSTED', 'Call did not fail within allowed time or number of retries');
INSERT INTO swoop.event_state VALUES ('INFO', 'Event is informational and does not change thread state');
INSERT INTO swoop.payload_cache VALUES ('ade69fe7-1d7d-472e-9f36-7242cc2aca77', '\x3eca96c5d2a3023ad5d7e06e7979c04b57162215', 'some_workflow', '2023-04-28 15:49:00+00', NULL);
INSERT INTO swoop.thread_p2023_04 VALUES ('2023-04-28 15:49:00+00', '2023-04-28 15:49:00+00', '81842304-0aa9-4609-89f0-1c86819b0752', 'handler_foo', 100, 'PENDING', NULL, NULL, 2, NULL);
INSERT INTO swoop.thread_p2023_04 VALUES ('2023-04-28 15:49:00+00', '2023-04-28 15:49:03+00', '2595f2da-81a6-423c-84db-935e6791046e', 'handler_foo', 100, 'SUCCESSFUL', NULL, NULL, 1, NULL);
SELECT pg_catalog.setval('swoop.thread_lock_id_seq', 2, true);
