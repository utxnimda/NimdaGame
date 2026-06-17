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
ASSET_LIBRARY_ROOT = GAME_ROOT / "ui_pipeline" / "asset_libraries"
ASSET_LIBRARY_INDEX_PATH = ASSET_LIBRARY_ROOT / "index.json"
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}
AUDIO_SUFFIXES = {".ogg", ".wav", ".mp3"}
FONT_SUFFIXES = {".ttf", ".otf", ".woff", ".woff2"}
VECTOR_SUFFIXES = {".svg"}


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
    register_style = bool(manifest.get("register_style", bool(manifest.get("components"))))
    writes_skin = bool(manifest.get("components") or register_style)
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
    if writes_skin and style_dir.exists() and not args.overwrite:
        print(f"ERROR: Style already exists. Re-run with --overwrite: {relative(style_dir)}")
        return 1

    generated_dir.mkdir(parents=True, exist_ok=True)

    component_catalog = {
        component["id"]: component
        for component in read_json(COMPONENT_CATALOG_PATH).get("components", [])
        if isinstance(component, dict) and "id" in component
    }
    copied = copy_component_assets(manifest, source_root, generated_dir, component_catalog)
    asset_libraries = copy_asset_libraries(manifest, source_root, generated_dir)
    copy_license_files(manifest, source_root, generated_dir)

    if asset_libraries:
        asset_library_json = build_asset_library_json(manifest, style_id, asset_libraries)
        ASSET_LIBRARY_ROOT.mkdir(parents=True, exist_ok=True)
        asset_library_path = ASSET_LIBRARY_ROOT / f"{style_id}.json"
        write_json(asset_library_path, asset_library_json)
        update_asset_library_index(style_id, str(asset_library_json.get("label", style_id)), asset_library_path)

    if writes_skin:
        style_dir.mkdir(parents=True, exist_ok=True)
        style_json = build_style_json(manifest, style_id)
        skin_json = build_skin_json(manifest, style_id, copied, component_catalog, asset_libraries)
        write_json(style_dir / "style.json", style_json)
        write_json(style_dir / "skin.json", skin_json)
        if register_style:
            update_style_index(style_id, str(style_json.get("label", style_id)))

    print(f"Imported {style_id}")
    if writes_skin:
        print(f"Wrote {relative(style_dir / 'style.json')}")
        print(f"Wrote {relative(style_dir / 'skin.json')}")
    if asset_libraries:
        print(f"Wrote {relative(ASSET_LIBRARY_ROOT / f'{style_id}.json')}")
    print(f"Copied {len(copied)} assets into {relative(generated_dir)}")
    if asset_libraries:
        library_count = sum(len(library.get("assets", [])) for library in asset_libraries)
        print(f"Indexed {library_count} library assets")
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
    for library in manifest.get("asset_libraries", []):
        library_root = source_root / str(library.get("source_root", ""))
        if not library_root.exists():
            errors.append(f"Missing asset library source root: {library_root}")
            continue
        matches = list(iter_library_files(library_root, library.get("patterns", ["**/*"])))
        if not matches:
            errors.append(f"Asset library has no matching files: {library_root}")
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


def copy_asset_libraries(
    manifest: dict[str, Any],
    source_root: Path,
    generated_dir: Path,
) -> list[dict[str, Any]]:
    copied_libraries: list[dict[str, Any]] = []
    for library in manifest.get("asset_libraries", []):
        library_id = str(library.get("id", "library"))
        library_root = source_root / str(library.get("source_root", ""))
        output_dir = generated_dir / "library" / str(library.get("output_dir", library_id))
        assets: list[dict[str, Any]] = []
        for source_file in iter_library_files(library_root, library.get("patterns", ["**/*"])):
            relative_source = source_file.relative_to(library_root)
            output_path = output_dir / relative_source
            output_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_file, output_path)
            asset_type = infer_asset_type(source_file)
            asset = {
                "id": asset_id_for(relative_source),
                "type": asset_type,
                "path": resource_path(output_path),
                "source": str(Path(str(library.get("source_root", ""))) / relative_source).replace("\\", "/"),
            }
            if asset_type == "image":
                asset["image"] = asset["path"]
            elif asset_type == "audio":
                asset["audio"] = asset["path"]
            assets.append(asset)
        copied_libraries.append(
            {
                "id": library_id,
                "label": library.get("label", library_id),
                "asset_type": library.get("asset_type", "mixed"),
                "assets": assets,
            }
        )
    return copied_libraries


def iter_library_files(library_root: Path, patterns: Any) -> list[Path]:
    pattern_values = patterns if isinstance(patterns, list) else [str(patterns)]
    matches: dict[str, Path] = {}
    for pattern in pattern_values:
        for candidate in library_root.glob(str(pattern)):
            if candidate.is_file():
                matches[str(candidate.resolve()).lower()] = candidate
    return [matches[key] for key in sorted(matches)]


def infer_asset_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in IMAGE_SUFFIXES:
        return "image"
    if suffix in AUDIO_SUFFIXES:
        return "audio"
    if suffix in FONT_SUFFIXES:
        return "font"
    if suffix in VECTOR_SUFFIXES:
        return "vector"
    return "file"


def asset_id_for(path: Path) -> str:
    normalized = str(path).replace("\\", "/").lower()
    return "".join(character if character.isalnum() else "_" for character in normalized).strip("_")


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
                copy_text_license(candidate, license_dir / f"{archive_id}_{candidate.name}")


def copy_text_license(source: Path, target: Path) -> None:
    try:
        text = source.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        shutil.copy2(source, target)
        return
    normalized = "\n".join(line.rstrip() for line in text.splitlines()).strip() + "\n"
    target.write_text(normalized, encoding="utf-8")


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
    asset_libraries: list[dict[str, Any]] | None = None,
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

    skin = {
        "schema_version": 1,
        "id": style_id,
        "label": style.get("label", manifest.get("label", style_id)),
        "font_color": style.get("font_color", "#FFFFFF"),
        "muted_color": style.get("muted_color", "#AAAAAA"),
        "components": components,
        "slots": slots,
    }
    if asset_libraries:
        skin["asset_libraries"] = asset_libraries
    return skin


def build_asset_library_json(
    manifest: dict[str, Any],
    style_id: str,
    asset_libraries: list[dict[str, Any]],
) -> dict[str, Any]:
    style = manifest.get("style", {})
    return {
        "schema_version": 1,
        "id": style_id,
        "label": style.get("label", manifest.get("label", style_id)),
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
        "libraries": asset_libraries,
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


def update_asset_library_index(style_id: str, label: str, library_path: Path) -> None:
    index = read_json(ASSET_LIBRARY_INDEX_PATH)
    if not index:
        index = {"schema_version": 1, "libraries": []}
    libraries = index.setdefault("libraries", [])
    entry = {
        "id": style_id,
        "label": label,
        "library_path": resource_path(library_path),
    }
    for offset, existing in enumerate(libraries):
        if existing.get("id") == style_id:
            libraries[offset] = entry
            break
    else:
        libraries.append(entry)
    write_json(ASSET_LIBRARY_INDEX_PATH, index)


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
