"""Generate runtime JSON for the Godot project."""

from __future__ import annotations

import sys
from pathlib import Path

# Support both installed commands and direct script invocation.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from mygame_tools.rpg_editor_data import main as rpg_data_main


def main() -> int:
    return rpg_data_main(["generate", "--database", "all"])


if __name__ == "__main__":
    raise SystemExit(main())
