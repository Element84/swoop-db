#!/usr/bin/env python
"""
This script will either migrate or rollback the swoop database to a specified
migration version. The migration version, action type (of either migrate/rollback),
and an override parameter are all specified in the values.yml from the Swoop-DB helm
chart.

It requires the following environment variables be set:

    - PGHOST:
          Postgres K8s service name which will be used to connect to the database
    - PGUSER:
          name of the user (role) that will perform the migrations
    - PGPORT:
          port number of the database container
    - PGDATABASE: name of the database which will be used for migrations
    - Any additional libpq-supported connection parameters
          (https://www.postgresql.org/docs/current/libpq-envars.html)
"""
import argparse
import asyncio
import os
import sys

from buildpg import V, funcs, render

from swoop.db import SwoopDB

APPLICATION_ROLES = ["user_api", "user_caboose", "user_conductor"]


def stderr(*args, **kwargs) -> None:
    kwargs["file"] = sys.stderr
    print(*args, **kwargs)


def check_positive(value) -> int:
    ivalue = int(value)
    if ivalue <= 0:
        raise argparse.ArgumentTypeError(
            "%s is an invalid migration version number. Only \
                positive values are supported."
            % value
        )
    return ivalue


async def run_migrations() -> None:
    dbname: str = os.environ["PGDATABASE"]

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--action",
        choices=["migrate", "rollback"],
        help="An action to take, either migrate or rollback",
    )
    parser.add_argument(
        "--version",
        type=check_positive,
        help="The migration version to which to migrate/rollback the database",
    )

    parser.add_argument(
        "--wait_override",
        choices=["true", "false"],
        help="Override option to skip waiting for active connections to close. \
        If specified, it is true, and if not specified it is false.",
    )

    args = parser.parse_args()

    action = args.action
    version = args.version
    override = args.wait_override

    swoop_db = SwoopDB()

    if override == "true":
        stderr(f"Applying migrate/rollback on database {dbname} to version {version}")
        await swoop_db.migrate(target=version, database=dbname)
    else:
        async with swoop_db.get_db_connection(database="") as conn:
            # Wait for all active connections from user roles to be closed
            active = True
            roles_list = V("usename") == funcs.any(APPLICATION_ROLES)
            while active:
                q, p = render(
                    "SELECT * FROM pg_stat_activity WHERE datname = :db AND :un_clause",
                    db=dbname,
                    un_clause=roles_list,
                )

                records = await conn.fetch(q, *p)
                if len(records) == 0:
                    active = False

            if action == "migrate":
                stderr(f"Migrating database {dbname} to version {version}")
            elif action == "rollback":
                stderr(f"Rolling back database {dbname} to version {version}")
            else:
                stderr(
                    f"Applying migrate/rollback on database {dbname} to \
                    version {version}"
                )
            await swoop_db.migrate(target=version, database=dbname)


if __name__ == "__main__":
    asyncio.run(run_migrations())
