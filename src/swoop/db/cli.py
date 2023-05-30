import argparse

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


def get_cli() -> dbcli.DbamiCLI:
    dbcli.DbamiCLI.commands.pop("init")
    cli: dbcli.DbamiCLI = dbcli.DbamiCLI(
        prog="swoop-db", description="Custom dbami cli instance for swoop-db"
    )
    return cli
