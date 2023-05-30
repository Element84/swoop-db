from typing import NoReturn

from dbami.cli import DbamiCLI

from swoop.db.cli import get_cli


def main(argv=None) -> NoReturn:
    cli: DbamiCLI = get_cli()
    cli(argv)


if __name__ == "__main__":
    main()
