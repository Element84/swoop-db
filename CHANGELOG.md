
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v7.0.2] - 2023-07-12

### Changed

- Properly set required env vars in Dockerfile ([#22])

## [v7.0.1] - 2023-07-11

### Changed

- Use the same image version for all build stages in the Dockerfile (fixes an
  issue with libc not found) ([#21])

## [v7.0.0] - 2023-07-01

### ⚠️ Breaking Changes

The schema migration from version 6 to 7 requries truncating ALL data records
in the database. There is no forward migration for existing data, just the
schema.

### Added

- `started_at` field to `swoop.thread` set from `RUNNING` events via
  `update_thread` trigger ([#19])
- `handler_type` field to swoop.action table ([#19])
- `public.gen_uuid_v7` to generate v7 uuids for actions ([#20])
- `public.uuid_version` to extract the version from a uuid ([#20])
- `timestamp_from_uuid_v7` to extract the timestamp from a v7 uuid ([#20])

### Changed

- `workflow` type actions cannot have `parent_uuid` set ([#19])
- `swoop.action` field `action_uuid` to be constrained to v7 uuids, such that
  sorting on the field would also sort based on the `created_at` timestamp
  ([#20])
- dropped `swoop.payload_cache` field `payload_hash` and switched to enforcing
  v5 uuids for the `payload_uuid` identifier ([#20])

### Removed

- `input_item` and `item_payload` tables ([#19])


## [v2.0.0] - 2023-06-26

### Added

- `find_cached_action_for_payload` function (used for checking if a payload
  should be processed or if we should simply reference an existing action)
  ([#12], [#14])

### Changed

- `workflow_verions` moved from `payload_cache` table to `action` table ([#14])
- Update [dbami] dependency to v0.2.0 ([#15])
- Disable CLI command `new` unless editable install to prevent
  creating migration files in non-editable installs ([#15])
- Schema no longer needs to manage schema version table or updates ([#15])

### Removed

- `UNKNOWN` state removed from `event_state` ([#14])

## [v0.1.0] - 2023-05-31

Initial release

[unreleased]: https://github.com/element84/swoop-db/compare/v7.0.2...main
[v7.0.2]: https://github.com/element84/swoop-db/compare/v7.0.1...7.0.2
[v7.0.1]: https://github.com/element84/swoop-db/compare/v7.0.0...7.0.1
[v7.0.0]: https://github.com/element84/swoop-db/compare/v2.0.0...7.0.0
[v2.0.0]: https://github.com/element84/swoop-db/compare/v0.1.0...2.0.0
[v0.1.0]: https://github.com/element84/swoop-db/tree/v0.1.0

[#12]: https://github.com/Element84/swoop-db/pull/12
[#14]: https://github.com/Element84/swoop-db/pull/14
[#15]: https://github.com/Element84/swoop-db/pull/15
[#19]: https://github.com/Element84/swoop-db/pull/19
[#20]: https://github.com/Element84/swoop-db/pull/20
[#21]: https://github.com/Element84/swoop-db/pull/21
[#22]: https://github.com/Element84/swoop-db/pull/22

[dbami]: https://github.com/element84/dbami
