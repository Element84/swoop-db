# Releasing swoop-db

The swoop-db python package build/publish is triggered by publishing a GitHub
release. Use a tag for the release of the format `v<MAJOR>.<MINOR>.<PATCH>`,
such as v0.1.0.

Changes for each release should be tracked in [`CHANGELOG.md`](./CHANGELOG.md).
The notes for each release in GitHub should be adapted from the the changes in
the CHANGELOG.

## Package and schema versions

Ensure when releasing that the package major version is the same as the schema
version.

Schema changes are considered to always be breaking (from a semantic versioning
point of view). When releasing with a new schema ensure that the major version
is incremented to match the schema version. Any releases without a schema
change should not be more than a minor version release.

Major versions of releases should form a continuous sequence. That is, no
versions should not be skipped. If multiple migrations are contained within a
single release, consolidate them into a single migration before releasing to
ensure the major version will only be incremented by one.

If a release contains breaking changes but no schema changes, it is best to
wait for schema changes before releasing, or to insert an empty migration to
force a schema version bump.
