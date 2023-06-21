# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v2.0.0] - 2023-06-26

### Added

-

### Changed

- Update [dbami] dependency to v0.2.0 ([#15])
- Disable CLI command `new` unless editable install to prevent
  creating migration files in non-editable installs ([#15])
- Schema no longer needs to manage schema version table or updates ([#15])

## [v0.1.0] - 2023-05-31

Initial release

[unreleased]: https://github.com/element84/swoop-db/compare/v2.0.0...main
[v2.0.0]: https://github.com/element84/swoop-db/compare/v0.1.0...2.0.0
[v0.1.0]: https://github.com/element84/swoop-db/tree/v0.1.0

[#15]: https://github.com/Element84/swoop-db/pull/15

[dbami]: https://github.com/element84/dbami
