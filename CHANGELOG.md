# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/element84/swoop-db/compare/v2.0.0...main
[v2.0.0]: https://github.com/element84/swoop-db/compare/v0.1.0...2.0.0
[v0.1.0]: https://github.com/element84/swoop-db/tree/v0.1.0

[#12]: https://github.com/Element84/swoop-db/pull/12
[#14]: https://github.com/Element84/swoop-db/pull/14
[#15]: https://github.com/Element84/swoop-db/pull/15

[dbami]: https://github.com/element84/dbami
