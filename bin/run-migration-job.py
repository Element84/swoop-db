#!/usr/bin/env python
"""
This script automates applying migrations to a swoop database as created by
./db-initialization.py. By default it will migrate the database forward to
the most-recent schema version after waiting for all swoop application
connections to be closed, but a few environment variables can be used to
change that default behavior:

    - ROLLBACK: boolean flag required when target version is less than current
    - VERSION: the migration version to which to migrate/rollback the database
    - NO_WAIT: override option to skip waiting for active connections to close

The script uses standard libpq-supported connection environment variables
(https://www.postgresql.org/docs/current/libpq-envars.html), so specify these
as required to connect to the database. Common vars include:

    - PGHOST: hostname or IP address of the postgres cluster host
    - PGPORT: port number of the postgres server
    - PGUSER: name of the user (role) that will perform the migrations
    - PGPASSWORD: password of the user (role)
    - PGDATABASE: name of the database onto which to apply migrations
"""
import asyncio
import os
import sys
import time

import asyncpg
from buildpg import V, render

from swoop.db import SwoopDB

SWOOP_RW_ROLE_NAME = "swoop_readwrite"


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


async def grant_connect_privileges(
    conn: asyncpg.Connection,
) -> None:
    q, p = render(
        """
            DO $_$
                BEGIN
                    EXECUTE FORMAT('GRANT CONNECT on database %s TO :rw',
                    CURRENT_DATABASE());
                END
            $_$;
        """,
        rw=V(SWOOP_RW_ROLE_NAME),
    )
    await conn.execute(q, *p)


async def revoke_connect_privileges(
    conn: asyncpg.Connection,
) -> None:
    q, p = render(
        """
            DO $_$
                BEGIN
                    EXECUTE FORMAT('REVOKE CONNECT on database %s FROM :rw',
                    CURRENT_DATABASE());
                END
            $_$;
        """,
        rw=V(SWOOP_RW_ROLE_NAME),
    )
    await conn.execute(q, *p)


async def active_connections_exist(conn):
    return await conn.fetchval(
        """
        SELECT EXISTS(
            SELECT * FROM pg_stat_activity
            WHERE
                datname = current_database()
                AND usename != current_user
        )
        """,
    )


async def wait_for_other_connections_to_close(conn):
    await revoke_connect_privileges(conn)

    while await active_connections_exist(conn):
        time.sleep(2)


async def run_migrations() -> None:
    rollback = strtobool(os.environ.get("ROLLBACK", "false"))
    version = int_or_none(os.environ.get("VERSION"))
    wait = not strtobool(os.environ.get("NO_WAIT", "false"))

    swoop_db = SwoopDB()

    async with swoop_db.get_db_connection() as conn:
        try:
            current_version = await swoop_db.get_current_version(conn=conn)
            if current_version == version:
                return

            if wait:
                await wait_for_other_connections_to_close(conn)

            if rollback:
                stderr(f"Rolling back database to version {version}")
                direction = "down"
            else:
                stderr(f"Migrating database to version {version}")
                direction = "up"

            await swoop_db.migrate(target=version, direction=direction, conn=conn)
        finally:
            await grant_connect_privileges(conn)


if __name__ == "__main__":
    asyncio.run(run_migrations())
