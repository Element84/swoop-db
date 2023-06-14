import pytest

from swoop.db import SwoopDB


# a little test to make sure the database is properly set up for pgtap tests
@pytest.mark.asyncio
async def test_has_pgtap_db(pgtap_db) -> None:
    async with SwoopDB.get_db_connection(database=pgtap_db) as conn:
        await conn.execute("select * from swoop.event;")
    assert True


@pytest.mark.asyncio
async def test_verify(pg_dump) -> None:
    assert await SwoopDB().verify(pg_dump=pg_dump)

@pytest.mark.asyncio
async def test_load_fixture() -> None:
    try:
        test_db = SwoopDB()
        await test_db.create_database('swoop')
        await test_db.load_schema()
        await test_db.load_fixture('base_01')
        await test_db.drop_database('swoop')
    except Exception as exc:
        assert False, f"Fixture could not be applied to database: {exc}"



