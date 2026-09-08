"""Release integration must stop before exporting invalid runtime data."""

import argparse
from pathlib import Path

import pytest

from mygame_tools import database, release_pipeline


def test_export_stops_when_data_preparation_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (tmp_path / "export_presets.cfg").write_text("", encoding="utf-8")
    config = release_pipeline.ReleaseConfig(
        project_name="Test",
        godot_project_dir=tmp_path,
        artifact_root=tmp_path,
        targets=(
            release_pipeline.ReleaseTarget(
                "test", "Test", "Test", tmp_path / "game.exe", tmp_path / "game.zip"
            ),
        ),
    )
    args = argparse.Namespace(godot_bin=None, targets=[], version="0.1.0")
    monkeypatch.setattr(release_pipeline, "find_godot", lambda _explicit: "godot")

    def invalid_data(_spec: database.DatabaseSpec) -> Path:
        raise database.DataValidationError("Invalid actor data")

    def unexpected_export(*_args: object, **_kwargs: object) -> None:
        pytest.fail("Godot must not export when runtime data preparation fails")

    monkeypatch.setattr(database, "generate_database", invalid_data)
    monkeypatch.setattr(release_pipeline.subprocess, "run", unexpected_export)
    assert release_pipeline.cmd_export(args, config) == 1
