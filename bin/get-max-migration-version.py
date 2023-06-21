#!/usr/bin/env python
from swoop.db import SwoopDB

print(max(SwoopDB().migrations.keys()))
