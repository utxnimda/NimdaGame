"""Repository paths shared by tools, independent of the working directory."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_CLIENT_ROOT = REPO_ROOT / "clients" / "godot"


def resolve_path(path: Path) -> Path:
    return path if path.is_absolute() else REPO_ROOT / path


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def resolve_resource_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT_CLIENT_ROOT / path.removeprefix("res://")
    return resolve_path(Path(path))
