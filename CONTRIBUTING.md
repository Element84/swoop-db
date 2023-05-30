# Contributing

## Project Setup

Configure your virtual environment of choice with Python >=3.9.

Install the project and its dependencies to your virtual environment with pip:

```commandline
pip install -r requirements.txt'
pip install -e '.[dev]'
```

Run pre-commit install to enable the pre-commit configuration:

```commandline
pre-commit install
```

The pre-commit hooks will be run against all files during a `git commit`, or
you can run it explicitly with:

```commandline
pre-commit run --all-files
```

If for some reason, you wish to commit code that does not pass the
pre-commit checks, this can be done with:

```commandline
git commit -m "message" --no-verify
```

### pre-commit hooks related to the database

We use `sqlfluff` for linting sql. See the root `.sqlfluff` config file and the
command defined in the `.pre-commit-config.yaml` for more information. Note
that the tool is a bit slow and somewhat inaccurate at times; it is better than
nothing but we should not hesitate to replace it with a better option if one
becomes available.

## Testing

Tests are run using `pytest`. Put `pytest` python modules and other resource in
the `tests/` directory.

`pgTap` tests are also handled by `pytest`, and are located in `tests/pgtap/`.
Ensure any and all schema changes are adequately covered by pgTap tests. See
the [`pgTap` documentation](https://pgtap.org/documentation.html) for further
`pgTap` information and examples.

It's best to keep each file short and focused with a descriptive name. Each
file can contain multiple `pgTap` tests, but will be executed by `pytest` as a
single test case. Also note that a `pgTap` planning error (a different number
of tests planned than run) will result in a test failure (with a descriptive
error message).

## Adding a migration

Use `swoop-db` if needing to create a new migration. It will create both the up
and down files inside the python package migrations directory:

```shell
swoop-db new <migration_name>
```
## Adding/updating dependencies

### Updating `requirements.txt` to latest versions

All dependencies should be specified in the project's `pyproject.toml`. The
frozen `requirements.txt` file is generated from that list using the
`pip-compile` utility (from the dev dependency `pip-tools`). Simply run:

```commandline
pip-compile --extra snyk
```

### Updating package pinning

To change a package minimum or maximum version, edit the pinning specified in
`pyproject.toml` then run `pip-compile` as above.

### Adding a new package

To add a new package as a project dependency, edit the `pyproject.toml` and add
it to the corresponding dependeny list. Run `pip-compile` as above to update
`requirements.txt` with the new package.
