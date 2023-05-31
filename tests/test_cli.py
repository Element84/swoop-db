from swoop.db.__main__ import main


def test_cli_main():
    try:
        main()
    except SystemExit as e:
        rc = e.code
    assert rc == 2
