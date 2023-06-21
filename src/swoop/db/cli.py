import argparse
import json
from importlib import metadata

import dbami.cli as dbcli

from swoop.db import SwoopDB

SWOOP_DB_ENV_PREFIX = "SWOOP_DB"


class SwoopArgs(dbcli.Arguments):
    env_prefix: str = SWOOP_DB_ENV_PREFIX

    @classmethod
    def project(cls, parser: argparse.ArgumentParser) -> None:
        # we don't use the project arg because that is hard-coded
        pass

    @classmethod
    def version_table(cls, parser: argparse.ArgumentParser) -> None:
        # we don't use the version table arg because that is hard-coded
        pass

    @classmethod
    def process_project(
        cls,
        parser: argparse.ArgumentParser,
        args: argparse.Namespace,
    ) -> None:
        args.db = SwoopDB()


class SwoopCommand(dbcli.DbamiCommand):
    def process_args(
        self, parser: argparse.ArgumentParser, args: argparse.Namespace
    ) -> None:
        args.schema_version_table = None
        super().process_args(parser, args)


# maybe this is indicative of an issue, but mypy doesn't like
# this monkey patching, so we explicitly ignore the type errors
dbcli.Arguments = SwoopArgs  # type: ignore
dbcli.DbamiCommand = SwoopCommand  # type: ignore


def is_editable_install(pkg_name: str) -> bool:
    dist = metadata.distribution(pkg_name)
    return (
        json.loads(dist.read_text("direct_url.json") or "{}")
        .get("dir_info", {})
        .get("editable", False)
    )


def get_cli() -> dbcli.DbamiCLI:
    # by definition swoop.db has a project, we don't want init
    dbcli.DbamiCLI.commands.pop("init")

    # we don't want to create new migrations in a non-editable install
    if not is_editable_install(__package__):
        dbcli.DbamiCLI.commands.pop("new")

    return dbcli.DbamiCLI(
        prog="swoop-db",
        description="Custom dbami cli instance for swoop-db",
    )
