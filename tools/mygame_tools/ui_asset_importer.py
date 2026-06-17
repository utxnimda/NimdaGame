"""Import external UI asset packs into the NimdaGame UI pipeline."""

from __future__ import annotations

import argparse
import json
import shutil
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

try:
    from mygame_tools.ui_pipeline import (
        COMPONENT_CATALOG_PATH,
        GAME_ROOT,
        REPO_ROOT,
        STYLE_INDEX_PATH,
        read_json,
        relative,
    )
except ModuleNotFoundError:
    from ui_pipeline import (
        COMPONENT_CATALOG_PATH,
        GAME_ROOT,
        REPO_ROOT,
        STYLE_INDEX_PATH,
        read_json,
        relative,
    )


MANIFEST_ROOT = GAME_ROOT / "ui_pipeline" / "import_manifests"
DEFAULT_SOURCE_ROOT = REPO_ROOT / "dist" / "ui_pipeline" / "external_sources"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_cmd = subparsers.add_parser("list", help="List available import manifests.")
    list_cmd.set_defaults(func=cmd_list)

    import_cmd = subparsers.add_parser("import", help="Import a UI asset manifest.")
    import_cmd.add_argument("manifest", help="Manifest id or JSON path.")
    import_cmd.add_argument("--source-root", default="", help="Directory containing extracted archive folders.")
    import_cmd.add_argument("--download", action="store_true", help="Download and extract archive URLs first.")
    import_cmd.add_argument("--overwrite", action="store_true", help="Overwrite generated style files.")
    import_cmd.set_defaults(func=cmd_import)

    args = parser.parse_args(argv)
    return args.func(args)


def cmd_list(_args: argparse.Namespace) -> int:
    for manifest_path in sorted(MANIFEST_ROOT.glob("*.json")):
        manifest = read_json(manifest_path)
        print(f"- {manifest.get('id', manifest_path.stem)}: {manifest.get('label', '')}")
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    manifest_path = resolve_manifest_path(args.manifest)
    manifest = read_json(manifest_path)
    if not manifest:
        print(f"ERROR: Manifest is empty or invalid: {relative(manifest_path)}")
        return 1

    style = manifest.get("style", {})
    style_id = str(style.get("id", manifest.get("id", manifest_path.stem)))
    source_root = resolve_source_root(args.source_root, style_id)

    if args.download:
        download_archives(manifest, source_root)

    errors = validate_sources(manifest, source_root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    style_dir = GAME_ROOT / "ui_pipeline" / "styles" / style_id
    generated_dir = GAME_ROOT / "ui_pipeline" / "generated" / style_id / "external"
    if style_dir.exists() and not args.overwrite:
        print(f"ERROR: Style already exists. Re-run with --overwrite: {relative(style_dir)}")
        return 1

    style_dir.mkdir(parents=True, exist_ok=True)
    generated_dir.mkdir(parents=True, exist_ok=True)

    component_catalog = {
        component["id"]: component
        for component in read_json(COMPONENT_CATALOG_PATH).get("components", [])
        if isinstance(component, dict) and "id" in component
    }
    copied = copy_component_assets(manifest, source_root, generated_dir, component_catalog)
    copy_license_files(manifest, source_root, generated_dir)

    style_json = build_style_json(manifest, style_id)
    skin_json = build_skin_json(manifest, style_id, copied, component_catalog)
    write_json(style_dir / "style.json", style_json)
    write_json(style_dir / "skin.json", skin_json)
    update_style_index(style_id, str(style_json.get("label", style_id)))

    print(f"Imported {style_id}")
    print(f"Wrote {relative(style_dir / 'style.json')}")
    print(f"Wrote {relative(style_dir / 'skin.json')}")
    print(f"Copied {len(copied)} assets into {relative(generated_dir)}")
    return 0


def resolve_manifest_path(value: str) -> Path:
    path = Path(value)
    if path.suffix == ".json" or path.is_absolute() or "\\" in value or "/" in value:
        return path if path.is_absolute() else REPO_ROOT / path
    return MANIFEST_ROOT / f"{value}.json"


def resolve_source_root(source_root: str, style_id: str) -> Path:
    if source_root:
        path = Path(source_root)
        return path if path.is_absolute() else REPO_ROOT / path
    return DEFAULT_SOURCE_ROOT / style_id


def download_archives(manifest: dict[str, Any], source_root: Path) -> None:
    source_root.mkdir(parents=True, exist_ok=True)
    for archive in manifest.get("archives", []):
        archive_id = str(archive.get("id", ""))
        url = str(archive.get("url", ""))
        if not archive_id or not url:
            continue
        zip_path = source_root / f"{archive_id}.zip"
        extract_path = source_root / archive_id
        print(f"Downloading {archive_id}...")
        urllib.request.urlretrieve(url, zip_path)
        if extract_path.exists():
            shutil.rmtree(extract_path)
        extract_path.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path) as archive_file:
            archive_file.extractall(extract_path)


def validate_sources(manifest: dict[str, Any], source_root: Path) -> list[str]:
    errors: list[str] = []
    if not source_root.exists():
        errors.append(f"Source root does not exist: {source_root}")
        return errors
    for asset in manifest.get("components", []):
        source = source_root / str(asset.get("source", ""))
        if not source.exists():
            errors.append(f"Missing source asset: {source}")
    return errors


def copy_component_assets(
    manifest: dict[str, Any],
    source_root: Path,
    generated_dir: Path,
    component_catalog: dict[str, dict[str, Any]],
) -> dict[tuple[str, str], dict[str, Any]]:
    copied: dict[tuple[str, str], dict[str, Any]] = {}
    for asset in manifest.get("components", []):
        component_id = str(asset.get("component", ""))
        state = str(asset.get("state", "normal"))
        source = source_root / str(asset.get("source", ""))
        suffix = source.suffix.lower() or ".png"
        output_name = str(asset.get("output_name", f"{component_id}_{state}{suffix}"))
        output_path = generated_dir / output_name
        shutil.copy2(source, output_path)
        copied[(component_id, state)] = {
            "image": resource_path(output_path),
            "nine_patch": asset.get(
                "nine_patch",
                component_catalog.get(component_id, {}).get("nine_patch", [0, 0, 0, 0]),
            ),
        }
        if asset.get("tint"):
            copied[(component_id, state)]["tint"] = asset["tint"]
    return copied


def copy_license_files(manifest: dict[str, Any], source_root: Path, generated_dir: Path) -> None:
    license_dir = generated_dir / "licenses"
    for archive in manifest.get("archives", []):
        archive_id = str(archive.get("id", ""))
        archive_root = source_root / archive_id
        if not archive_root.exists():
            continue
        for candidate in archive_root.iterdir():
            if candidate.is_file() and candidate.name.lower().startswith("license"):
                license_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(candidate, license_dir / f"{archive_id}_{candidate.name}")


def build_style_json(manifest: dict[str, Any], style_id: str) -> dict[str, Any]:
    style = manifest.get("style", {})
    return {
        "schema_version": 1,
        "id": style_id,
        "label": style.get("label", manifest.get("label", style_id)),
        "reference_mode": style.get("reference_mode", "external_asset_pack"),
        "style_prompt": style.get("style_prompt", ""),
        "negative_prompt": style.get("negative_prompt", ""),
        "output_contract": style.get(
            "output_contract",
            {
                "format": "png",
                "transparent_background": True,
                "safe_border_px": 4,
                "naming": "{style_id}_{slot_id}.png",
            },
        ),
        "source": {
            "type": "external_asset_pack",
            "manifest": f"res://ui_pipeline/import_manifests/{manifest.get('id', style_id)}.json",
            "licenses": sorted(
                {
                    archive.get("license", "")
                    for archive in manifest.get("archives", [])
                    if archive.get("license")
                }
            ),
        },
    }


def build_skin_json(
    manifest: dict[str, Any],
    style_id: str,
    copied: dict[tuple[str, str], dict[str, Any]],
    component_catalog: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    style = manifest.get("style", {})
    components: dict[str, Any] = {}
    for (component_id, state), asset in copied.items():
        component = components.setdefault(
            component_id,
            {
                "kind": component_catalog.get(component_id, {}).get("kind", "panel"),
                "nine_patch": asset.get(
                    "nine_patch",
                    component_catalog.get(component_id, {}).get("nine_patch", [0, 0, 0, 0]),
                ),
                "states": {},
            },
        )
        component["states"][state] = {"image": asset["image"]}
        if asset.get("tint"):
            component["states"][state]["tint"] = asset["tint"]

    slots: dict[str, Any] = {}
    for slot in manifest.get("legacy_slots", []):
        component_id = str(slot.get("component", ""))
        state = str(slot.get("state", "normal"))
        copied_asset = copied.get((component_id, state), {})
        slots[str(slot.get("slot", component_id))] = {
            "image": copied_asset.get("image", ""),
            "color": slot.get("color", "#FFFFFF"),
            "border": slot.get("border", "#000000"),
        }

    return {
        "schema_version": 1,
        "id": style_id,
        "label": style.get("label", manifest.get("label", style_id)),
        "font_color": style.get("font_color", "#FFFFFF"),
        "muted_color": style.get("muted_color", "#AAAAAA"),
        "components": components,
        "slots": slots,
    }


def update_style_index(style_id: str, label: str) -> None:
    index = read_json(STYLE_INDEX_PATH)
    styles = index.setdefault("styles", [])
    entry = {
        "id": style_id,
        "label": label,
        "style_path": f"res://ui_pipeline/styles/{style_id}/style.json",
        "skin_path": f"res://ui_pipeline/styles/{style_id}/skin.json",
    }
    for offset, existing in enumerate(styles):
        if existing.get("id") == style_id:
            styles[offset] = entry
            break
    else:
        styles.append(entry)
    write_json(STYLE_INDEX_PATH, index)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def resource_path(path: Path) -> str:
    resolved = path.resolve()
    game_root = GAME_ROOT.resolve()
    try:
        return "res://" + str(resolved.relative_to(game_root)).replace("\\", "/")
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
