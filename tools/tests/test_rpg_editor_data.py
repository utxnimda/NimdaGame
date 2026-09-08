from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

from mygame_tools.database import (
    DatabaseSpec,
    DataValidationError,
    generate_database,
    load_and_validate,
    replace_database,
)
from mygame_tools.databases import validate_actors
from mygame_tools.paths import REPO_ROOT


def _payload(actor_id: str = "actor_test") -> dict:
    return {
        "schema_version": 1,
        "actors": [
            {
                "id": actor_id,
                "legacy_id": 1,
                "name": "Test Actor",
                "nickname": "",
                "profile": "",
                "class_id": "class_adventurer",
                "initial_level": 1,
                "max_level": 99,
                "assets": {
                    "portrait": "",
                    "map_sprite": "",
                    "battle_sprite": "",
                },
                "base_stats": {
                    "max_hp": 100,
                    "max_mp": 20,
                    "attack": 10,
                    "defense": 10,
                    "magic_attack": 10,
                    "magic_defense": 10,
                    "agility": 10,
                    "luck": 10,
                },
            }
        ],
    }


def _spec(tmp_path: Path) -> DatabaseSpec:
    return DatabaseSpec(
        name="actors",
        source_path=tmp_path / "actors.yaml",
        schema_path=REPO_ROOT / "data" / "schemas" / "actor_database.schema.json",
        output_path=tmp_path / "generated" / "actors.json",
        collection_key="actors",
        semantic_validator=validate_actors,
    )


def _write_yaml(path: Path, payload: dict) -> None:
    path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")


def test_generate_actor_database(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())

    output_path = generate_database(spec)
    generated = json.loads(output_path.read_text(encoding="utf-8"))

    assert generated["content_type"] == "actors"
    assert len(generated["source_hash"]) == 64
    assert generated["actors"][0]["id"] == "actor_test"


def test_duplicate_actor_id_is_rejected(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    payload = _payload()
    payload["actors"].append(payload["actors"][0].copy())
    _write_yaml(spec.source_path, payload)

    with pytest.raises(DataValidationError, match="duplicate id"):
        load_and_validate(spec)


def test_replace_database_writes_yaml_and_runtime_json(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    replacement = _payload("actor_replaced")
    replacement_path = tmp_path / "replacement.json"
    replacement_path.write_text(json.dumps(replacement), encoding="utf-8")

    replace_database(spec, replacement_path)

    authored = yaml.safe_load(spec.source_path.read_text(encoding="utf-8"))
    generated = json.loads(spec.output_path.read_text(encoding="utf-8"))
    assert authored["actors"][0]["id"] == "actor_replaced"
    assert generated["actors"][0]["id"] == "actor_replaced"


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("initial_level", 100, "initial_level must not exceed max_level"),
        ("name", "   ", "name must not be blank"),
        ("max_level", 0, "less than the minimum"),
        ("id", "invalid", "does not match"),
    ],
)
def test_invalid_replacement_preserves_both_files(
    tmp_path: Path, field: str, value: object, message: str
) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    generate_database(spec)
    before = (spec.source_path.read_bytes(), spec.output_path.read_bytes())
    payload = _payload()
    payload["actors"][0][field] = value
    incoming = tmp_path / "input.json"
    incoming.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(DataValidationError, match=message):
        replace_database(spec, incoming)

    assert (spec.source_path.read_bytes(), spec.output_path.read_bytes()) == before


def test_runtime_preparation_failure_does_not_change_source(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    original = spec.source_path.read_bytes()
    spec.output_path.parent.write_text("This file blocks output directory creation.")
    incoming = tmp_path / "input.json"
    incoming.write_text(json.dumps(_payload("actor_replaced")), encoding="utf-8")

    with pytest.raises(OSError):
        replace_database(spec, incoming)

    assert spec.source_path.read_bytes() == original
    assert not list(tmp_path.glob(".actors.yaml.*"))


def test_failed_runtime_commit_restores_source(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    generate_database(spec)
    before = (spec.source_path.read_bytes(), spec.output_path.read_bytes())
    incoming = tmp_path / "input.json"
    incoming.write_text(json.dumps(_payload("actor_replaced")), encoding="utf-8")
    original_replace = Path.replace

    def fail_runtime_replace(path: Path, target: Path) -> Path:
        if target == spec.output_path:
            raise PermissionError("Runtime file is locked")
        return original_replace(path, target)

    monkeypatch.setattr(Path, "replace", fail_runtime_replace)
    with pytest.raises(PermissionError, match="locked"):
        replace_database(spec, incoming)

    assert (spec.source_path.read_bytes(), spec.output_path.read_bytes()) == before
    assert not list(tmp_path.rglob(".actors.*"))


def test_stale_save_preserves_external_changes(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    generate_database(spec)
    generated = json.loads(spec.output_path.read_text(encoding="utf-8"))
    incoming = tmp_path / "input.json"
    incoming.write_text(json.dumps(_payload("actor_editor")), encoding="utf-8")
    _write_yaml(spec.source_path, _payload("actor_external"))
    before = (spec.source_path.read_bytes(), spec.output_path.read_bytes())

    with pytest.raises(DataValidationError, match="Source changed"):
        replace_database(spec, incoming, expected_source_hash=generated["source_hash"])

    assert (spec.source_path.read_bytes(), spec.output_path.read_bytes()) == before


def test_save_updates_hash_from_exact_source_bytes(tmp_path: Path) -> None:
    import hashlib

    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    generate_database(spec)
    previous = json.loads(spec.output_path.read_text(encoding="utf-8"))
    incoming = tmp_path / "input.json"
    payload = _payload("actor_updated")
    payload["actors"][0]["name"] = "\u661f\u5149"
    incoming.write_text(json.dumps(payload), encoding="utf-8")

    replace_database(spec, incoming, expected_source_hash=previous["source_hash"])

    generated = json.loads(spec.output_path.read_text(encoding="utf-8"))
    assert generated["source_hash"] == hashlib.sha256(spec.source_path.read_bytes()).hexdigest()
    assert generated["source_hash"] != previous["source_hash"]
    assert generated["actors"] == payload["actors"]


def test_invalid_yaml_has_a_validation_error_and_preserves_runtime(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    _write_yaml(spec.source_path, _payload())
    generate_database(spec)
    before = spec.output_path.read_bytes()
    spec.source_path.write_text("actors: [", encoding="utf-8")

    with pytest.raises(DataValidationError, match="Invalid YAML"):
        generate_database(spec)

    assert spec.output_path.read_bytes() == before


def test_another_database_does_not_inherit_actor_rules(tmp_path: Path) -> None:
    schema_path = tmp_path / "items.schema.json"
    schema_path.write_text(
        json.dumps(
            {
                "type": "object",
                "required": ["schema_version", "items"],
                "properties": {
                    "schema_version": {"const": 1},
                    "items": {"type": "array", "items": {"type": "object"}},
                },
            }
        ),
        encoding="utf-8",
    )
    spec = DatabaseSpec(
        "items", tmp_path / "items.yaml", schema_path, tmp_path / "items.json", "items"
    )
    # These fields have no level semantics for this database.
    payload = {
        "schema_version": 1,
        "items": [{"id": "item_a", "initial_level": 10, "max_level": 1}],
    }
    _write_yaml(spec.source_path, payload)

    generate_database(spec)

    generated = json.loads(spec.output_path.read_text(encoding="utf-8"))
    assert generated["content_type"] == "items"
    assert generated["items"] == payload["items"]


def test_cli_reports_missing_dependencies_without_traceback(tmp_path: Path) -> None:
    import subprocess
    import sys

    result = subprocess.run(
        [
            sys.executable,
            "-S",
            str(REPO_ROOT / "tools/mygame_tools/rpg_editor_data.py"),
            "validate",
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1
    assert "Missing dependencies" in result.stderr
    assert "Traceback" not in result.stderr
