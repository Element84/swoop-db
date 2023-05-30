from pathlib import Path

from dbami.db import DB


class SwoopDB(DB):
    def __init__(self):
        super().__init__(
            project=Path(__file__).parent,
            schema_version_table="swoop.schema_version",
        )
