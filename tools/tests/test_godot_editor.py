"""Behavior checks for the editor, using a fake data client to avoid authored writes."""

import shutil
import subprocess

import pytest

from mygame_tools.paths import GODOT_CLIENT_ROOT, REPO_ROOT


def test_editor_behaviors() -> None:
    godot = shutil.which("godot") or shutil.which("godot4")
    if godot is None:
        pytest.skip("Godot is not installed; run the documented headless checks locally.")
    script = REPO_ROOT / "tools" / "godot" / "test_rpg_editor.gd"
    result = subprocess.run(
        [
            godot,
            "--headless",
            "--path",
            str(GODOT_CLIENT_ROOT),
            "--script",
            str(script),
            "--quit-after",
            "300",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    # Godot may report script failures without a nonzero process exit code.
    assert "SCRIPT ERROR" not in output, output
    assert "RPG editor behavior checks passed." in output, output
