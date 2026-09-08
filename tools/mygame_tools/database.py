"""Reusable schema validation and persistence for authored YAML databases.

DatabaseSpec supplies paths and optional domain validation. Generated JSON and
its source hash always derive from the same snapshot of the source bytes.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any

import yaml
from jsonschema import Draft202012Validator

SemanticValidator = Callable[[dict[str, Any]], list[str]]


class DataValidationError(ValueError):
    """Authored data does not satisfy its schema or domain rules."""


class DataConflictError(DataValidationError):
    """The authored file changed since it was loaded by the editor."""


@dataclass(frozen=True)
class DatabaseSpec:
    name: str
    source_path: Path
    schema_path: Path
    output_path: Path
    collection_key: str
    semantic_validator: SemanticValidator | None = None


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _parse_yaml(source: bytes, path: Path) -> Any:
    try:
        return yaml.safe_load(source.decode("utf-8"))
    except (yaml.YAMLError, UnicodeError) as exc:
        raise DataValidationError(f"Invalid YAML in {path}: {exc}") from exc


def read_yaml(path: Path) -> Any:
    return _parse_yaml(path.read_bytes(), path)


def validate_payload(payload: Any, spec: DatabaseSpec) -> None:
    validator = Draft202012Validator(read_json(spec.schema_path))
    errors = sorted(validator.iter_errors(payload), key=lambda error: error.json_path)
    messages = [f"{error.json_path}: {error.message}" for error in errors]

    # Domain validators receive schema-valid records.
    if not messages and isinstance(payload, dict):
        seen_ids: set[str] = set()
        for index, record in enumerate(payload[spec.collection_key]):
            record_id = record.get("id")
            if isinstance(record_id, str):
                if record_id in seen_ids:
                    messages.append(
                        f"{spec.collection_key}[{index}].id: duplicate id '{record_id}'"
                    )
                seen_ids.add(record_id)
        if spec.semantic_validator is not None:
            messages.extend(spec.semantic_validator(payload))

    if messages:
        raise DataValidationError("\n".join(messages))


def _validated_source(spec: DatabaseSpec) -> tuple[dict[str, Any], bytes]:
    source = spec.source_path.read_bytes()
    payload = _parse_yaml(source, spec.source_path)
    validate_payload(payload, spec)
    return payload, source


def load_and_validate(spec: DatabaseSpec) -> dict[str, Any]:
    payload, _source = _validated_source(spec)
    return payload


def _runtime_bytes(payload: dict[str, Any], source: bytes, spec: DatabaseSpec) -> bytes:
    runtime_payload = {
        "schema_version": payload["schema_version"],
        "content_type": spec.name,
        "source_hash": hashlib.sha256(source).hexdigest(),
        spec.collection_key: payload[spec.collection_key],
    }
    return (json.dumps(runtime_payload, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


@contextmanager
def _staged_file(target: Path, content: bytes) -> Iterator[Path]:
    """Stage beside the destination to keep replacement on one filesystem."""
    target.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=target.parent, prefix=f".{target.name}.", delete=False) as file:
        temporary = Path(file.name)
    try:
        temporary.write_bytes(content)
        yield temporary
    finally:
        temporary.unlink(missing_ok=True)


def generate_database(spec: DatabaseSpec) -> Path:
    payload, source = _validated_source(spec)
    with _staged_file(spec.output_path, _runtime_bytes(payload, source, spec)) as staged:
        staged.replace(spec.output_path)
    return spec.output_path


def replace_database(
    spec: DatabaseSpec,
    input_path: Path,
    *,
    expected_source_hash: str | None = None,
) -> Path:
    """Save validated data, restoring the source if runtime replacement fails.

    Both outputs and a rollback copy are staged before changing the source.
    This handles ordinary I/O failures, not process crashes or simultaneous
    writers. Runtime JSON remains rebuildable from the authoritative YAML.
    """
    payload = read_json(input_path)
    validate_payload(payload, spec)
    original = spec.source_path.read_bytes() if spec.source_path.exists() else None
    if expected_source_hash is not None:
        current_hash = hashlib.sha256(original).hexdigest() if original is not None else None
        if current_hash != expected_source_hash:
            raise DataConflictError("Source changed outside the editor. Reload before saving.")

    source = yaml.safe_dump(
        payload, allow_unicode=True, sort_keys=False, default_flow_style=False
    ).encode("utf-8")
    runtime = _runtime_bytes(payload, source, spec)
    with (
        _staged_file(spec.source_path, source) as staged_source,
        _staged_file(spec.output_path, runtime) as staged_runtime,
        _staged_file(spec.source_path, original or b"") as backup,
    ):
        current = spec.source_path.read_bytes() if spec.source_path.exists() else None
        if current != original:
            raise DataConflictError("Source changed during save. Reload before saving.")
        staged_source.replace(spec.source_path)
        try:
            staged_runtime.replace(spec.output_path)
        except OSError:
            if original is None:
                spec.source_path.unlink()
            else:
                backup.replace(spec.source_path)
            raise
    return spec.output_path
