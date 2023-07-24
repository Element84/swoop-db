import asyncio
import os

from buildpg import V, asyncpg, render

DB_NAME = "test"


def db_initialization():
    async def setup():
        dsn = "postgresql://postgres:password@postgres:5432/postgres"
        conn = await asyncpg.connect(dsn=dsn)

        # Create Owner Role

        owner_role_un = os.environ["OWNER_ROLE_USER"]

        q, p = render(
            """
                CREATE ROLE :un WITH CREATEDB CREATEROLE LOGIN PASSWORD ':pw';
            """,
            un=V(owner_role_un),
            pw=V(os.environ["OWNER_ROLE_PASS"]),
        )

        await conn.execute(q, *p)

        # Create Swoop API Role

        q, p = render(
            """
                CREATE ROLE :un WITH LOGIN IN ROLE :ir PASSWORD ':pw';
            """,
            un=V(os.environ["API_ROLE_USER"]),
            pw=V(os.environ["API_ROLE_PASS"]),
            ir=V(owner_role_un),
        )

        await conn.execute(q, *p)

        # Create Caboose Role

        q, p = render(
            """
                CREATE ROLE :un WITH LOGIN IN ROLE :ir PASSWORD ':pw';
            """,
            un=V(os.environ["CABOOSE_ROLE_USER"]),
            pw=V(os.environ["CABOOSE_ROLE_PASS"]),
            ir=V(owner_role_un),
        )

        await conn.execute(q, *p)

        # Create Conductor Role

        q, p = render(
            """
                CREATE ROLE :un WITH LOGIN IN ROLE :ir PASSWORD ':pw';
            """,
            un=V(os.environ["CONDUCTOR_ROLE_USER"]),
            pw=V(os.environ["CONDUCTOR_ROLE_PASS"]),
            ir=V(owner_role_un),
        )

        await conn.execute(q, *p)

        # Create database with owner role as owner

        q, p = render(
            """
                CREATE DATABASE :db WITH OWNER :dbo;
            """,
            db=V(DB_NAME),
            dbo=V(owner_role_un),
        )

        await conn.execute(q, *p)

        await conn.close()

    asyncio.run(setup())


if __name__ == "__main__":
    db_initialization()
