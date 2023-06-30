import re
from pathlib import Path

import pytest
from dbami.pg_dump import pg_dump as _pg_dump

from swoop.db import SwoopDB


@pytest.fixture(scope="session")
def migration_fixtures(pytestconfig) -> Path:
    return pytestconfig.rootpath.joinpath("tests", "fixtures", "migrations")


def uuid_replacer(instr: str) -> str:
    uuids: list[str] = re.findall(
        r"'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'",
        instr,
    )

    for index, uuid in enumerate(uuids):
        instr = instr.replace(uuid, f"'uuid{index}'")

    return instr


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "start,end,result_editor",
    [
        (0, 1, None),
        (0, 2, None),
        (2, 6, None),
        (6, 7, uuid_replacer),
    ],
)
async def test_migration(start, end, result_editor, migration_fixtures, pg_dump):
    if result_editor is None:

        def result_editor(x):
            return x

    fixture = migration_fixtures.joinpath(f"{start}_base_01.sql")
    result = migration_fixtures.joinpath(f"{end}_result.sql")
    DB_NAME = f"swoop_test_migration_{start}_{end}"
    test_db = SwoopDB()

    dump_args = [
        "--inserts",
        "--data-only",
        "--exclude-table",
        test_db.schema_version_table,
    ]

    try:
        await test_db.create_database(DB_NAME)
        await test_db.migrate(target=start, database=DB_NAME)
        await test_db.execute_sql(fixture.read_text(), database=DB_NAME)
        await test_db.migrate(target=end, database=DB_NAME)
        rc, dump = await _pg_dump("-d", DB_NAME, *dump_args, pg_dump=pg_dump)
    finally:
        await test_db.drop_database(DB_NAME)

    if rc != 0:
        raise Exception(f"pg_dump returned non-zero: {rc}")

    dump = "".join(
        [
            line + "\n"
            for line in dump.splitlines()
            if line and not line.startswith("--")
        ]
    )

    assert result_editor(dump) == result_editor(result.read_text())
