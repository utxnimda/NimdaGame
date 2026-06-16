"""Build, package, and release helper for NimdaGame."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from mygame_tools.validate_plugins import validate_plugin_layout
    from mygame_tools.ui_pipeline import validate_ui_pipeline
except ModuleNotFoundError:
    from validate_plugins import validate_plugin_layout
    from ui_pipeline import validate_ui_pipeline


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG_PATH = REPO_ROOT / "release" / "release_targets.json"
DEFAULT_VERSION = "0.1.0"


@dataclass(frozen=True)
class ReleaseTarget:
    id: str
    label: str
    preset: str
    export_path: Path
    package_path: Path


@dataclass(frozen=True)
class ReleaseConfig:
    project_name: str
    godot_project_dir: Path
    artifact_root: Path
    targets: tuple[ReleaseTarget, ...]


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    config = load_config(Path(args.config))
    return args.func(args, config)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=str(DEFAULT_CONFIG_PATH),
        help="Path to release target config.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser("plan", help="Print configured release targets.")
    plan.set_defaults(func=cmd_plan)

    check = subparsers.add_parser("check", help="Check repository and release prerequisites.")
    check.add_argument("--strict", action="store_true", help="Fail if Godot export prerequisites are missing.")
    check.set_defaults(func=cmd_check)

    export = subparsers.add_parser("export", help="Export one or more Godot targets.")
    _add_target_args(export)
    export.set_defaults(func=cmd_export)

    package = subparsers.add_parser("package", help="Package exported target directories.")
    _add_target_args(package)
    package.set_defaults(func=cmd_package)

    notes = subparsers.add_parser("notes", help="Generate release notes.")
    notes.add_argument("--version", default=DEFAULT_VERSION)
    notes.set_defaults(func=cmd_notes)

    publish = subparsers.add_parser("publish", help="Create a GitHub release from packages.")
    publish.add_argument("--version", default=DEFAULT_VERSION)
    publish.add_argument("--execute", action="store_true", help="Run gh release create instead of printing it.")
    publish.set_defaults(func=cmd_publish)

    all_cmd = subparsers.add_parser("all", help="Export, package, and generate notes.")
    _add_target_args(all_cmd)
    all_cmd.set_defaults(func=cmd_all)

    return parser


def _add_target_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("targets", nargs="*", help="Target IDs. Defaults to all targets.")
    parser.add_argument("--version", default=DEFAULT_VERSION)
    parser.add_argument("--godot-bin", default=None, help="Path to Godot executable. Overrides GODOT_BIN.")


def load_config(path: Path) -> ReleaseConfig:
    config_path = resolve_path(path)
    with config_path.open("r", encoding="utf-8") as file:
        raw = json.load(file)

    targets: list[ReleaseTarget] = []
    for target in raw["targets"]:
        targets.append(
            ReleaseTarget(
                id=target["id"],
                label=target["label"],
                preset=target["preset"],
                export_path=resolve_path(Path(target["export_path"])),
                package_path=resolve_path(Path(target["package_path"])),
            )
        )

    return ReleaseConfig(
        project_name=raw["project_name"],
        godot_project_dir=resolve_path(Path(raw["godot_project_dir"])),
        artifact_root=resolve_path(Path(raw["artifact_root"])),
        targets=tuple(targets),
    )


def resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def cmd_plan(_args: argparse.Namespace, config: ReleaseConfig) -> int:
    print(f"Project: {config.project_name}")
    print(f"Godot project: {relative(config.godot_project_dir)}")
    print(f"Artifacts: {relative(config.artifact_root)}")
    print("")
    for target in config.targets:
        print(f"- {target.id}: {target.label}")
        print(f"  preset: {target.preset}")
        print(f"  export: {relative(target.export_path)}")
        print(f"  package: {relative(target.package_path)}")
    return 0


def cmd_check(args: argparse.Namespace, config: ReleaseConfig) -> int:
    errors: list[str] = []
    warnings: list[str] = []

    _require_file(config.godot_project_dir / "project.godot", errors)
    _require_file(config.godot_project_dir / "scenes" / "app" / "main.tscn", errors)
    _require_file(config.godot_project_dir / "plugins" / "enabled_plugins.json", errors)
    _require_file(REPO_ROOT / "docs" / "demo_plan.md", errors)
    _require_file(REPO_ROOT / "release" / "release_targets.json", errors)
    _require_file(REPO_ROOT / "tools" / "ai_providers" / "openai_images.json", errors)
    _require_file(REPO_ROOT / "tools" / "ai_providers" / "gemini_images.json", errors)

    plugin_result = validate_plugin_layout()
    errors.extend(plugin_result.errors)
    warnings.extend(plugin_result.warnings)

    ui_result = validate_ui_pipeline()
    errors.extend(ui_result.errors)
    warnings.extend(ui_result.warnings)

    export_presets = config.godot_project_dir / "export_presets.cfg"
    if not export_presets.exists():
        warnings.append(
            "Missing game/export_presets.cfg. Create Godot export presets before running export."
        )

    godot_bin = find_godot(None)
    if godot_bin is None:
        warnings.append("Godot executable not found. Set GODOT_BIN or add Godot to PATH before export.")

    if not git_is_clean():
        warnings.append("Git working tree has local changes. Release builds should come from a clean commit.")

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)

    if errors or (args.strict and warnings):
        return 1

    print("Release check completed.")
    return 0


def cmd_export(args: argparse.Namespace, config: ReleaseConfig) -> int:
    godot_bin = find_godot(args.godot_bin)
    if godot_bin is None:
        print("ERROR: Godot executable not found. Set GODOT_BIN or pass --godot-bin.", file=sys.stderr)
        return 1

    export_presets = config.godot_project_dir / "export_presets.cfg"
    if not export_presets.exists():
        print("ERROR: game/export_presets.cfg is missing. Create export presets in Godot first.", file=sys.stderr)
        return 1

    for target in select_targets(config, args.targets):
        output_path = format_versioned_path(target.export_path, args.version)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        command = [
            godot_bin,
            "--headless",
            "--path",
            str(config.godot_project_dir),
            "--export-release",
            target.preset,
            str(output_path),
        ]
        print_command(command)
        subprocess.run(command, cwd=REPO_ROOT, check=True)

    return 0


def cmd_package(args: argparse.Namespace, config: ReleaseConfig) -> int:
    for target in select_targets(config, args.targets):
        export_path = format_versioned_path(target.export_path, args.version)
        export_dir = export_path.parent
        package_path = format_versioned_path(target.package_path, args.version)

        if not export_dir.exists():
            print(f"ERROR: Export directory does not exist: {relative(export_dir)}", file=sys.stderr)
            return 1

        package_path.parent.mkdir(parents=True, exist_ok=True)
        zip_directory(export_dir, package_path)
        print(f"Packaged {target.id}: {relative(package_path)}")

    return 0


def cmd_notes(args: argparse.Namespace, config: ReleaseConfig) -> int:
    notes_path = write_release_notes(config, args.version)
    print(f"Wrote {relative(notes_path)}")
    return 0


def cmd_publish(args: argparse.Namespace, config: ReleaseConfig) -> int:
    package_paths = [
        format_versioned_path(target.package_path, args.version)
        for target in config.targets
        if format_versioned_path(target.package_path, args.version).exists()
    ]

    if not package_paths:
        print("ERROR: No package artifacts found. Run package first.", file=sys.stderr)
        return 1

    notes_path = release_notes_path(args.version)
    if not notes_path.exists():
        notes_path = write_release_notes(config, args.version)

    tag = f"v{args.version}"
    command = [
        "gh",
        "release",
        "create",
        tag,
        *[str(path) for path in package_paths],
        "--title",
        f"{config.project_name} {args.version}",
        "--notes-file",
        str(notes_path),
    ]

    if not args.execute:
        print("Dry run. Review this command, then rerun with --execute:")
        print_command(command)
        return 0

    if shutil.which("gh") is None:
        print("ERROR: GitHub CLI 'gh' was not found.", file=sys.stderr)
        return 1

    print_command(command)
    subprocess.run(command, cwd=REPO_ROOT, check=True)
    return 0


def cmd_all(args: argparse.Namespace, config: ReleaseConfig) -> int:
    export_result = cmd_export(args, config)
    if export_result != 0:
        return export_result

    package_result = cmd_package(args, config)
    if package_result != 0:
        return package_result

    return cmd_notes(args, config)


def _require_file(path: Path, errors: list[str]) -> None:
    if not path.exists():
        errors.append(f"Missing required file: {relative(path)}")


def find_godot(explicit: str | None) -> str | None:
    if explicit:
        return explicit

    env_path = os.environ.get("GODOT_BIN")
    if env_path:
        return env_path

    candidates = [
        "godot",
        "godot4",
        "godot_console",
        "Godot_v4.6-stable_win64_console",
        "Godot_v4.6-stable_win64",
    ]
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    return None


def git_is_clean() -> bool:
    try:
        result = subprocess.run(
            ["git", "status", "--short"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False
    return result.stdout.strip() == ""


def select_targets(config: ReleaseConfig, requested: Iterable[str]) -> tuple[ReleaseTarget, ...]:
    requested_ids = tuple(requested)
    if not requested_ids:
        return config.targets

    by_id = {target.id: target for target in config.targets}
    missing = [target_id for target_id in requested_ids if target_id not in by_id]
    if missing:
        raise SystemExit(f"Unknown target id: {', '.join(missing)}")

    return tuple(by_id[target_id] for target_id in requested_ids)


def format_versioned_path(path: Path, version: str) -> Path:
    return Path(str(path).format(version=version))


def zip_directory(source_dir: Path, zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source_dir))


def write_release_notes(config: ReleaseConfig, version: str) -> Path:
    template_path = REPO_ROOT / "release" / "release_notes_template.md"
    with template_path.open("r", encoding="utf-8") as file:
        template = file.read()

    artifacts = "\n".join(
        f"- {target.label}: `{relative(format_versioned_path(target.package_path, version))}`"
        for target in config.targets
    )
    notes_path = release_notes_path(version)
    notes_path.parent.mkdir(parents=True, exist_ok=True)
    notes_path.write_text(
        template.format(version=version, artifacts=artifacts),
        encoding="utf-8",
    )
    return notes_path


def release_notes_path(version: str) -> Path:
    return REPO_ROOT / "dist" / "releases" / version / "release-notes.md"


def print_command(command: Iterable[str]) -> None:
    print(" ".join(_quote(part) for part in command))


def _quote(value: str) -> str:
    if " " not in value:
        return value
    return f'"{value}"'


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
