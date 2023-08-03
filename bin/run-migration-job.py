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
    - ACTION: name of the action performed, either migrate or rollback
    - VERSION: the migration version to which to migrate/rollback the database
    - NO_WAIT: override option to skip waiting for active connections to close.
    - Any additional libpq-supported connection parameters
          (https://www.postgresql.org/docs/current/libpq-envars.html)
"""
import asyncio
import os
import sys
import time

from swoop.db import SwoopDB


def stderr(*args, **kwargs) -> None:
    kwargs["file"] = sys.stderr
    print(*args, **kwargs)


def strtobool(val) -> bool:
    """Convert a string representation of truth to true or false.
    True values are 'y', 'yes', 't', 'true', 'on', and '1'; false values
    are 'n', 'no', 'f', 'false', 'off', and '0'.  Raises ValueError if
    'val' is anything else.
    """
    val = val.lower()
    if val in ("y", "yes", "t", "true", "on", "1"):
        return True
    elif val in ("n", "no", "f", "false", "off", "0"):
        return False
    else:
        raise ValueError(f"invalid boolean value {val!r}")


def int_or_none(val):
    return int(val) if val else None


async def run_migrations() -> None:
    dbname: str = os.environ["PGDATABASE"]

    rollback = strtobool(os.environ.get("ROLLBACK", "false"))
    version = int_or_none(os.environ.get("VERSION"))
    no_wait = strtobool(os.environ.get("NO_WAIT", "false"))

    swoop_db = SwoopDB()

    async with swoop_db.get_db_connection() as conn:
        current_version = await swoop_db.get_current_version(conn=conn)
        if current_version == version:
            return
        # Wait for all active connections from user roles to be closed
        active_sessions = not no_wait
        while active_sessions:
            active_sessions = await conn.fetchval(
                """
                SELECT EXISTS(
                    SELECT * FROM pg_stat_activity
                    WHERE
                        datname = current_database()
                        AND usename != current_user
                )
                """,
            )
            if active_sessions:
                time.sleep(2)

        if rollback:
            stderr(f"Rolling back database {dbname} to version {version}")
            direction = "down"
        else:
            stderr(f"Migrating database {dbname} to version {version}")
            direction = "up"

        await swoop_db.migrate(
            target=version, direction=direction, database=dbname, conn=conn
        )


if __name__ == "__main__":
    asyncio.run(run_migrations())
