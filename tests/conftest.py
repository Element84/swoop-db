import os
import shutil
import tempfile
from contextlib import AsyncExitStack
from pathlib import Path

import asyncpg
import pytest
from dbami.util import random_name, syncrun

from swoop.db import SwoopDB

PGTAP_DB_NAME = random_name("swoop_db_test")


@pytest.fixture(scope="session")
def pg_dump(pytestconfig):
    env_pgd = os.getenv("SWOOP_DB_PG_DUMP", "pg_dump")

    if shutil.which(env_pgd):
        yield env_pgd
        return

    # we don't have pg_dump on the path
    # fallback to a tmp script
    with tempfile.TemporaryDirectory() as d:
        pgd = Path(d).joinpath("pg_dump")
        pgd.write_text(
            f"""#!/bin/sh
cd "{pytestconfig.rootpath}"
docker compose exec postgres pg_dump "$@"
"""
        )
        pgd.chmod(0o755)
        yield str(pgd)


@pytest.fixture(scope="session")
def pgtap_db():
    return PGTAP_DB_NAME


def pytest_configure(config):
    db = SwoopDB()

    async def setup():
        async with db.get_db_connection(database=PGTAP_DB_NAME) as conn:
            await conn.execute("CREATE SCHEMA tap;")
            await conn.execute("CREATE EXTENSION pgtap SCHEMA tap;")
            await db.load_schema(conn=conn)

    syncrun(db.create_database(PGTAP_DB_NAME))
    syncrun(setup())
    return PGTAP_DB_NAME


def pytest_unconfigure(config):
    db = SwoopDB()
    try:
        syncrun(db.drop_database(PGTAP_DB_NAME))
    except asyncpg.InvalidCatalogNameError:
        pass


def pytest_collect_file(parent, file_path):
    if file_path.suffix == ".sql" and file_path.name.startswith("test"):
        return SqlFile.from_parent(parent, path=file_path)


async def run_test(sql: str):
    import sqlparse
    import tap.line
    from tap.parser import Parser

    async with AsyncExitStack() as stack:
        conn = await stack.enter_async_context(
            SwoopDB().get_db_connection(database=PGTAP_DB_NAME)
        )
        transaction = conn.transaction()
        await transaction.start()

        try:
            for statement in sqlparse.split(sql):
                result = await conn.fetchval(statement)

                for parsed in Parser().parse_text(result):
                    if isinstance(parsed, tap.line.Result):
                        if not parsed.ok:
                            raise SqlException(parsed.description, statement)

                    elif isinstance(parsed, tap.line.Diagnostic):
                        raise PgTapDiagnostic(parsed.text)

                    elif isinstance(parsed, tap.line.Plan):
                        pass

                    else:
                        raise TypeError(
                            f"Unhandled tap type '{parsed.category}': {result}",
                        )
        finally:
            await transaction.rollback()


class SqlFile(pytest.File):
    def collect(self):
        yield SqlItem.from_parent(self, name=self.path.stem)


class SqlItem(pytest.Item):
    def runtest(self):
        syncrun(run_test(self.path.read_text()))

    def repr_failure(self, exc_info):
        """Called when self.runtest() raises an exception."""
        if isinstance(exc_info.value, PgTapException):
            self.add_report_section("output", "pgTap", str(exc_info.value))
            return
        return super().repr_failure(exc_info)

    def reportinfo(self):
        return self.path, None, f"{self.name}"


class PgTapException(Exception):
    pass


class SqlException(PgTapException):
    def __init__(self, description, statement):
        import textwrap

        super().__init__(
            """pgTap test failure!
    {}
from test statement
{}
""".format(
                description, textwrap.indent(statement, " " * 4)
            )
        )


class PgTapDiagnostic(PgTapException):
    def __init__(self, description):
        super().__init__(
            """pgTap error!
    {}
""".format(
                description
            )
        )
