"""Validate NimdaGame runtime plugin manifests."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
ENABLED_PLUGINS_PATH = REPO_ROOT / "game" / "plugins" / "enabled_plugins.json"
SUPPORTED_IMPLEMENTATIONS = {"gdscript", "native", "external_script"}


@dataclass(frozen=True)
class PluginValidationResult:
    errors: tuple[str, ...]
    warnings: tuple[str, ...]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--enabled", default=str(ENABLED_PLUGINS_PATH))
    args = parser.parse_args(argv)

    result = validate_plugin_layout(Path(args.enabled))
    for error in result.errors:
        print(f"ERROR: {error}")
    for warning in result.warnings:
        print(f"WARNING: {warning}")

    if result.errors:
        return 1

    print("Plugin validation completed.")
    return 0


def validate_plugin_layout(enabled_path: Path = ENABLED_PLUGINS_PATH) -> PluginValidationResult:
    errors: list[str] = []
    warnings: list[str] = []

    enabled = _read_json(resolve_path(enabled_path), errors)
    if not isinstance(enabled, dict):
        errors.append(f"Enabled plugin file must contain an object: {relative(resolve_path(enabled_path))}")
        return PluginValidationResult(tuple(errors), tuple(warnings))

    plugin_paths = enabled.get("plugins", [])
    if not isinstance(plugin_paths, list):
        errors.append("Enabled plugin file field 'plugins' must be an array.")
        return PluginValidationResult(tuple(errors), tuple(warnings))

    seen_ids: set[str] = set()
    for manifest_path_value in plugin_paths:
        if not isinstance(manifest_path_value, str):
            errors.append("Enabled plugin manifest paths must be strings.")
            continue

        manifest_path = resolve_resource_path(manifest_path_value)
        manifest = _read_json(manifest_path, errors)
        if not isinstance(manifest, dict):
            errors.append(f"Plugin manifest must contain an object: {relative(manifest_path)}")
            continue

        _validate_manifest(manifest_path, manifest, seen_ids, errors, warnings)

    return PluginValidationResult(tuple(errors), tuple(warnings))


def _validate_manifest(
    manifest_path: Path,
    manifest: dict[str, Any],
    seen_ids: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    plugin_id = _required_string(manifest, "id", manifest_path, errors)
    _required_string(manifest, "name", manifest_path, errors)
    _required_string(manifest, "version", manifest_path, errors)

    if plugin_id:
        if plugin_id in seen_ids:
            errors.append(f"Duplicate plugin id: {plugin_id}")
        seen_ids.add(plugin_id)

    implementation = manifest.get("implementation")
    if not isinstance(implementation, dict):
        errors.append(f"Plugin {relative(manifest_path)} missing object field 'implementation'.")
        return

    implementation_type = implementation.get("type")
    if implementation_type not in SUPPORTED_IMPLEMENTATIONS:
        errors.append(
            f"Plugin {relative(manifest_path)} has unsupported implementation type: {implementation_type}"
        )
        return

    if implementation_type == "gdscript":
        entry = implementation.get("entry")
        if not isinstance(entry, str) or not entry:
            errors.append(f"GDScript plugin {plugin_id} missing implementation.entry.")
        elif not resolve_resource_path(entry).exists():
            errors.append(f"GDScript plugin {plugin_id} entry does not exist: {entry}")

    if implementation_type == "native":
        class_name = implementation.get("class_name")
        if not isinstance(class_name, str) or not class_name:
            errors.append(f"Native plugin {plugin_id} missing implementation.class_name.")

    if implementation_type == "external_script":
        command = implementation.get("command")
        if not isinstance(command, str) or not command:
            errors.append(f"External script plugin {plugin_id} missing implementation.command.")
        runtime = implementation.get("runtime", "editor_only")
        if runtime == "runtime":
            warnings.append(f"External script plugin {plugin_id} is marked runtime; verify export target support.")

    hooks = manifest.get("hooks")
    if not isinstance(hooks, dict):
        errors.append(f"Plugin {plugin_id} missing object field 'hooks'.")
        return

    for hook_id, hook_config in hooks.items():
        if not isinstance(hook_id, str) or not hook_id:
            errors.append(f"Plugin {plugin_id} has an invalid hook id.")
        if not isinstance(hook_config, dict):
            errors.append(f"Plugin {plugin_id} hook {hook_id} config must be an object.")
            continue
        priority = hook_config.get("priority", 100)
        if not isinstance(priority, int) or priority < 0:
            errors.append(f"Plugin {plugin_id} hook {hook_id} priority must be a non-negative integer.")

    tool_entry = manifest.get("tool_entry")
    if tool_entry is not None:
        if not isinstance(tool_entry, dict):
            errors.append(f"Plugin {plugin_id} tool_entry must be an object.")
            return
        scene_path = tool_entry.get("scene_path")
        if not isinstance(scene_path, str) or not scene_path:
            errors.append(f"Plugin {plugin_id} tool_entry missing scene_path.")
        elif not resolve_resource_path(scene_path).exists():
            errors.append(f"Plugin {plugin_id} tool_entry scene does not exist: {scene_path}")


def _required_string(
    manifest: dict[str, Any],
    field: str,
    manifest_path: Path,
    errors: list[str],
) -> str:
    value = manifest.get(field)
    if not isinstance(value, str) or not value:
        errors.append(f"Plugin {relative(manifest_path)} missing string field '{field}'.")
        return ""
    return value


def _read_json(path: Path, errors: list[str]) -> Any:
    if not path.exists():
        errors.append(f"JSON file does not exist: {relative(path)}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"Invalid JSON in {relative(path)}: {exc}")
        return None


def resolve_resource_path(path: str) -> Path:
    if path.startswith("res://"):
        return REPO_ROOT / "game" / path.removeprefix("res://")
    return resolve_path(Path(path))


def resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
