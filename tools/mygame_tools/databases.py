"""Database registration and domain rules; database.py owns storage."""

from typing import Any

from .database import DatabaseSpec
from .paths import GODOT_CLIENT_ROOT, REPO_ROOT


def validate_actors(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for index, actor in enumerate(payload["actors"]):
        if actor["initial_level"] > actor["max_level"]:
            errors.append(f"actors[{index}]: initial_level must not exceed max_level")
        if not actor["name"].strip():
            errors.append(f"actors[{index}].name: name must not be blank")
    return errors


DATABASES = {
    "actors": DatabaseSpec(
        name="actors",
        source_path=REPO_ROOT / "data" / "genres" / "turn_rpg" / "actors.yaml",
        schema_path=REPO_ROOT / "data" / "schemas" / "actor_database.schema.json",
        output_path=GODOT_CLIENT_ROOT / "data" / "generated" / "turn_rpg" / "actors.json",
        collection_key="actors",
        semantic_validator=validate_actors,
    )
}
