"""Command-line adapter for RPG database validation, generation, and editing."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Preserve direct-script invocation without requiring an editable install.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    # Compatibility exports for existing callers. New code imports database directly.
    from mygame_tools.database import DatabaseSpec as DatabaseSpec
    from mygame_tools.database import (
        DataValidationError,
        generate_database,
        replace_database,
    )
    from mygame_tools.database import load_and_validate as load_and_validate
    from mygame_tools.database import read_json as read_json
    from mygame_tools.database import read_yaml as read_yaml
    from mygame_tools.database import validate_payload as validate_payload
    from mygame_tools.databases import DATABASES
except ModuleNotFoundError as exc:
    if exc.name not in {"yaml", "jsonschema"}:
        raise
    _DEPENDENCY_ERROR = exc
else:
    _DEPENDENCY_ERROR = None

from mygame_tools.paths import REPO_ROOT as REPO_ROOT
from mygame_tools.paths import relative


def validate_databases(names: list[str]) -> None:
    for name in names:
        spec = DATABASES[name]
        load_and_validate(spec)
        print(f"Validated {relative(spec.source_path)}")


def generate_databases(names: list[str]) -> None:
    for name in names:
        print(f"Generated {relative(generate_database(DATABASES[name]))}")


def _database_names(value: str) -> list[str]:
    if value == "all":
        return list(DATABASES)
    if value not in DATABASES:
        raise DataValidationError(f"Unknown database: {value}")
    return [value]


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("validate", "generate"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--database", default="all", choices=["all", *DATABASES])

    replace = subparsers.add_parser("replace", help="Replace one authored database from JSON.")
    replace.add_argument("--database", required=True, choices=sorted(DATABASES))
    replace.add_argument("--input", required=True, type=Path)
    replace.add_argument("--expected-source-hash", help="Reject stale editor data before saving.")
    return parser


def main(argv: list[str] | None = None) -> int:
    if _DEPENDENCY_ERROR is not None:
        print(
            'ERROR: Missing dependencies. Run: python -m pip install -e "tools[dev]"',
            file=sys.stderr,
        )
        return 1
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "validate":
            validate_databases(_database_names(args.database))
        elif args.command == "generate":
            generate_databases(_database_names(args.database))
        elif args.command == "replace":
            spec = DATABASES[args.database]
            replace_database(
                spec, args.input.resolve(), expected_source_hash=args.expected_source_hash
            )
            print(f"Updated {relative(spec.source_path)}")
    except (DataValidationError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
