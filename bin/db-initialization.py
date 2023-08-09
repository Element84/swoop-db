#!/usr/bin/env python
"""
This script will create a new swoop database.
It requires the following environment variables be set:

    - PGDATABASE: name of the database to be created
    - API_ROLE_USER and API_ROLE_PASS:
          swoop-api role username and password
    - CABOOSE_ROLE_USER and CABOOSE_ROLE_PASS:
          swoop-caboose role username and password
    - CONDUCTOR_ROLE_USER and CONDUCTOR_ROLE_PASS:
          swoop-conductor role username and password
    - OWNER_ROLE_USER and OWNER_ROLE_PASS:
          username and password for owner role
    - Any additional libpq-supported connection parameters
          (https://www.postgresql.org/docs/current/libpq-envars.html)
"""
import asyncio
import os
import sys

import asyncpg
from buildpg import V, render

from swoop.db import SwoopDB

APPLICATION_ROLES: list[str] = [
    "API_ROLE",
    "CABOOSE_ROLE",
    "CONDUCTOR_ROLE",
]

SWOOP_RW_ROLE_NAME = "swoop_readwrite"


def stderr(*args, **kwargs) -> None:
    kwargs["file"] = sys.stderr
    print(*args, **kwargs)


async def create_owner_role(conn: asyncpg.Connection, owner_role_name: str) -> None:
    q, p = render(
        "CREATE ROLE :un WITH LOGIN PASSWORD ':pw'",
        un=V(owner_role_name),
        pw=V(os.environ["OWNER_ROLE_PASS"]),
    )
    await conn.execute(q, *p)


async def create_swoop_rw_role(conn: asyncpg.Connection, group_name: str) -> None:
    q, p = render(
        "CREATE ROLE :un",
        un=V(group_name),
    )
    await conn.execute(q, *p)


async def create_application_role(
    conn: asyncpg.Connection,
    role: str,
    group_name: str,
) -> None:
    q, p = render(
        "CREATE ROLE :un WITH LOGIN IN ROLE :ir PASSWORD ':pw'",
        un=V(os.environ[f"{role}_USER"]),
        pw=V(os.environ[f"{role}_PASS"]),
        ir=V(group_name),
    )
    await conn.execute(q, *p)


async def create_database(
    conn: asyncpg.Connection,
    dbname: str,
    owner_role_name: str,
) -> None:
    q, p = render(
        "CREATE DATABASE :db WITH OWNER :dbo",
        db=V(dbname),
        dbo=V(owner_role_name),
    )
    await conn.execute(q, *p)


async def post_create_init(conn: asyncpg.Connection, owner_role_name: str) -> None:
    q, p = render(
        """
        CREATE SCHEMA IF NOT EXISTS partman AUTHORIZATION :dbo;
        CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;
        GRANT ALL ON SCHEMA partman TO :dbo;
        GRANT ALL ON ALL TABLES IN SCHEMA partman TO :dbo;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA partman TO :dbo;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA partman TO :dbo;
        REVOKE ALL ON DATABASE swoop FROM PUBLIC;
        REVOKE CREATE ON SCHEMA public FROM PUBLIC;
        CREATE SCHEMA IF NOT EXISTS swoop AUTHORIZATION :dbo;
        GRANT :dbo TO current_user;
        SET ROLE :dbo;
        GRANT CONNECT ON DATABASE swoop TO swoop_readwrite;
        GRANT USAGE, CREATE ON SCHEMA swoop TO swoop_readwrite;
        ALTER DEFAULT PRIVILEGES IN SCHEMA swoop GRANT SELECT,
        INSERT, UPDATE, DELETE ON TABLES TO swoop_readwrite;
        ALTER DEFAULT PRIVILEGES IN SCHEMA swoop GRANT USAGE ON
        SEQUENCES TO swoop_readwrite;
        """,
        dbo=V(owner_role_name),
    )
    await conn.execute(q, *p)


async def db_initialization() -> None:
    dbname: str = os.environ["PGDATABASE"]
    owner: str = os.environ["OWNER_ROLE_USER"]

    async with SwoopDB.get_db_connection(database="postgres") as conn:
        try:
            stderr(f"Creating owner role '{owner}'...")
            await create_owner_role(conn, owner)
        except asyncpg.DuplicateObjectError:
            stderr("Owner already exists, skipping.")

        try:
            stderr(f"Creating swoop read/write role '{SWOOP_RW_ROLE_NAME}'...")
            await create_swoop_rw_role(conn, SWOOP_RW_ROLE_NAME)
        except asyncpg.DuplicateObjectError:
            stderr("Swoop read/write role already exists, skipping.")

        for role in APPLICATION_ROLES:
            try:
                stderr(f"Creating application role {role}...")
                await create_application_role(conn, role, SWOOP_RW_ROLE_NAME)
            except asyncpg.DuplicateObjectError:
                stderr("Role already exists, skipping.")

        try:
            stderr(f"Creating database '{dbname}'...")
            await create_database(conn, dbname, owner)
        except asyncpg.DuplicateDatabaseError:
            stderr("Database already exists, skipping.")

    async with SwoopDB.get_db_connection() as conn:
        await post_create_init(conn, owner)


if __name__ == "__main__":
    asyncio.run(db_initialization())
