# `swoop-db`

The swoop database schema is managed via
[`dbami`](https://github.com/element84/dbami), and uses `dbami` to implement a
custom cli and python library for managing databases for
[swoop](https://github.com/element84/swoop).

## Installing `swoop-db`

`swoop-db` can be `pip` installed:

```shell
pip install swoop.db
```

If wanting to install locally for development purposes, see
[`CONTRIBUTING.md`](./CONTRIBUTING.md) for further instructions.

## Postgres Extensions

`swoop-db` makes use of two postgres extensions:

* `pg_partman`: an automated table partition manager
* `pgTap`: a postgres-native testing framework

`pgTap` is only used for testing, and is not installed into the schema except
when testing.

## Database testing with docker

[`./Dockerfile`](./Dockerfile) defines the build steps for a database test
container. The container includes the requsite postgres extensions. As the
Dockerfile builds an image with all the database dependencies with fixed
versions, using docker with that image is strongly recommended for all testing
to help guarantee consistency between developers (running postgres in another
way is fine if desired, but does require that the necessary extensions and
utilities are installed, and that the connection information is correctly
configured for tooling).

To make using the docker container more convenient, a `docker-compose.yml` file
is provided in the project root. The repo contents are mounted as `/swoop/db/`
inside the container to help facilitate database operations and testing using
the included utilities. For example, to bring up the database and run the
tests:

```shell
# load the .env vars
source .env

# bring up the database container in the background
#   --build  forces rebuild of the container in case changes have been made
#   -V       recreates any volumes instead of reusing data
#   -d       run the composed images in daemon mode rather than in the foreground
docker compose up --build -V -d

# create the database and apply all migrations
swoop-db up

# connect to the database with psql
docker compose exec postgres psql -U postgres swoop

# create the database and load the schema.sql with a custom database name
swoop-db create --database swoop-custom
swoop-db load-schema --database swoop-custom
```

To verify the schema and migrations match:

```shell
# run the verification; any diff indicates schema/migrations out-of-sync
swoop-db verify
```

To drop a database:

```shell
# we'll drop the custom one we made earlier
swoop-db drop --database swoop-custom
```

To stop the postgres container:

```shell
docker compose down
```

The `swoop-db` cli is intended to be discoverable. When in doubt, try checking
the help.
