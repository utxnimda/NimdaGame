"""Validate and prepare NimdaGame UI generation pipeline data."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = REPO_ROOT / "game"
STYLE_INDEX_PATH = GAME_ROOT / "ui_pipeline" / "styles" / "index.json"
TEMPLATE_INDEX_PATH = GAME_ROOT / "ui_pipeline" / "templates" / "index.json"
ASSET_LIBRARY_INDEX_PATH = GAME_ROOT / "ui_pipeline" / "asset_libraries" / "index.json"
ASSET_SLOTS_PATH = GAME_ROOT / "ui_pipeline" / "asset_slots.json"
COMPONENT_CATALOG_PATH = GAME_ROOT / "ui_pipeline" / "component_catalog.json"
COMPILED_ROOT = GAME_ROOT / "ui_pipeline" / "compiled"


@dataclass(frozen=True)
class ValidationResult:
    errors: tuple[str, ...]
    warnings: tuple[str, ...]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_cmd = subparsers.add_parser("list", help="List UI styles and templates.")
    list_cmd.set_defaults(func=cmd_list)

    validate_cmd = subparsers.add_parser("validate", help="Validate UI pipeline data.")
    validate_cmd.set_defaults(func=cmd_validate)

    prompt_cmd = subparsers.add_parser("prompt-pack", help="Generate an AI prompt pack.")
    prompt_cmd.add_argument("--style", default="neon_arcade")
    prompt_cmd.add_argument("--output", default=str(REPO_ROOT / "dist" / "ui_pipeline"))
    prompt_cmd.add_argument("--legacy-slots", action="store_true", help="Generate old slot prompts instead of full UI kit prompts.")
    prompt_cmd.set_defaults(func=cmd_prompt_pack)

    kit_cmd = subparsers.add_parser("kit-plan", help="Print the component/state generation plan.")
    kit_cmd.add_argument("--style", default="megami_magazine")
    kit_cmd.set_defaults(func=cmd_kit_plan)

    compile_cmd = subparsers.add_parser("compile-kit", help="Compile a style skin into a normalized UI kit skin.")
    compile_cmd.add_argument("--style", default="megami_magazine")
    compile_cmd.add_argument("--output", default=str(COMPILED_ROOT))
    compile_cmd.set_defaults(func=cmd_compile_kit)

    args = parser.parse_args(argv)
    return args.func(args)


def cmd_list(_args: argparse.Namespace) -> int:
    styles = load_styles()
    templates = load_templates()
    print("Styles")
    for style in styles:
        print(f"- {style['id']}: {style['label']}")
    print("")
    print("Templates")
    for template in templates:
        print(f"- {template['id']}: {template['label']}")
    return 0


def cmd_validate(_args: argparse.Namespace) -> int:
    result = validate_ui_pipeline()
    for error in result.errors:
        print(f"ERROR: {error}")
    for warning in result.warnings:
        print(f"WARNING: {warning}")
    if result.errors:
        return 1
    print("UI pipeline validation completed.")
    return 0


def cmd_prompt_pack(args: argparse.Namespace) -> int:
    styles = {style["id"]: style for style in load_styles()}
    if args.style not in styles:
        print(f"ERROR: Unknown style: {args.style}")
        return 1

    style = read_json(resolve_resource_path(styles[args.style]["style_path"]))
    if args.legacy_slots:
        asset_slots = read_json(ASSET_SLOTS_PATH)["slots"]
        prompt_pack = build_prompt_pack(style, asset_slots)
    else:
        components = load_components()
        prompt_pack = build_kit_prompt_pack(style, components)

    output_dir = Path(args.output) / args.style
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "prompt_pack.json"
    markdown_path = output_dir / "prompt_pack.md"
    json_path.write_text(json.dumps(prompt_pack, indent=2, ensure_ascii=False), encoding="utf-8")
    markdown_path.write_text(render_prompt_pack_markdown(prompt_pack), encoding="utf-8")

    print(f"Wrote {relative(json_path)}")
    print(f"Wrote {relative(markdown_path)}")
    return 0


def cmd_kit_plan(args: argparse.Namespace) -> int:
    style = style_by_id(args.style)
    components = load_components()
    prompt_pack = build_kit_prompt_pack(style, components)
    print(f"Style: {prompt_pack['style_label']} ({prompt_pack['style_id']})")
    for prompt in prompt_pack["prompts"]:
        print(f"- {prompt['component_id']}.{prompt['state']} -> {prompt['output_name']}")
    return 0


def cmd_compile_kit(args: argparse.Namespace) -> int:
    style_entry = style_entry_by_id(args.style)
    style = read_json(resolve_resource_path(style_entry["style_path"]))
    skin = read_json(resolve_resource_path(style_entry["skin_path"]))
    components = load_components()
    compiled = compile_skin(style, skin, components)

    output_dir = Path(args.output) / args.style
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "compiled_skin.json"
    output_path.write_text(json.dumps(compiled, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {relative(output_path)}")
    return 0


def validate_ui_pipeline() -> ValidationResult:
    errors: list[str] = []
    warnings: list[str] = []

    styles = load_styles(errors)
    templates = load_templates(errors)
    asset_libraries = load_asset_libraries(errors)
    asset_slots = load_asset_slots(errors)
    components = load_components(errors)
    slot_ids = {slot.get("id") for slot in asset_slots if isinstance(slot, dict)}
    component_ids = {component.get("id") for component in components if isinstance(component, dict)}
    _validate_components(components, errors)

    seen_styles: set[str] = set()
    for style_entry in styles:
        style_id = _required_string(style_entry, "id", "style index entry", errors)
        _check_duplicate(style_id, seen_styles, "style", errors)
        style_path = _required_string(style_entry, "style_path", f"style {style_id}", errors)
        skin_path = _required_string(style_entry, "skin_path", f"style {style_id}", errors)
        style = read_json(resolve_resource_path(style_path), errors)
        skin = read_json(resolve_resource_path(skin_path), errors)
        _validate_style(style_id, style, errors)
        _validate_skin(style_id, skin, slot_ids, component_ids, errors, warnings)

    seen_templates: set[str] = set()
    for template_entry in templates:
        template_id = _required_string(template_entry, "id", "template index entry", errors)
        _check_duplicate(template_id, seen_templates, "template", errors)
        template_path = _required_string(template_entry, "path", f"template {template_id}", errors)
        template = read_json(resolve_resource_path(template_path), errors)
        _validate_template(template_id, template, slot_ids, component_ids, errors)

    seen_asset_libraries: set[str] = set()
    for library_entry in asset_libraries:
        library_id = _required_string(library_entry, "id", "asset library index entry", errors)
        _check_duplicate(library_id, seen_asset_libraries, "asset library", errors)
        library_path = _required_string(library_entry, "library_path", f"asset library {library_id}", errors)
        library = read_json(resolve_resource_path(library_path), errors)
        _validate_asset_library(library_id, library, errors)

    return ValidationResult(tuple(errors), tuple(warnings))


def load_styles(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(STYLE_INDEX_PATH, "styles", errors)


def load_templates(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(TEMPLATE_INDEX_PATH, "templates", errors)


def load_asset_libraries(errors: list[str] | None = None) -> list[dict[str, Any]]:
    if not ASSET_LIBRARY_INDEX_PATH.exists():
        return []
    return _load_index_array(ASSET_LIBRARY_INDEX_PATH, "libraries", errors)


def load_asset_slots(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(ASSET_SLOTS_PATH, "slots", errors)


def load_components(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(COMPONENT_CATALOG_PATH, "components", errors)


def style_entry_by_id(style_id: str) -> dict[str, Any]:
    styles = {style["id"]: style for style in load_styles()}
    if style_id not in styles:
        raise SystemExit(f"Unknown style: {style_id}")
    return styles[style_id]


def style_by_id(style_id: str) -> dict[str, Any]:
    return read_json(resolve_resource_path(style_entry_by_id(style_id)["style_path"]))


def build_prompt_pack(style: dict[str, Any], asset_slots: Iterable[dict[str, Any]]) -> dict[str, Any]:
    output_contract = style.get("output_contract", {})
    naming = output_contract.get("naming", "{style_id}_{slot_id}.png")
    prompts: list[dict[str, Any]] = []
    for slot in asset_slots:
        slot_id = str(slot.get("id", ""))
        prompts.append(
            {
                "slot_id": slot_id,
                "label": slot.get("label", slot_id),
                "prompt": f"{style.get('style_prompt', '')}, {slot.get('prompt', '')}",
                "negative_prompt": style.get("negative_prompt", ""),
                "output_name": naming.replace("{style_id}", str(style.get("id", ""))).replace(
                    "{slot_id}", slot_id
                ),
            }
        )
    return {
        "schema_version": 1,
        "style_id": style.get("id", ""),
        "style_label": style.get("label", ""),
        "reference_mode": style.get("reference_mode", "text_style"),
        "reference_image": style.get("reference_image", ""),
        "output_contract": output_contract,
        "mode": "legacy_slots",
        "prompts": prompts,
    }


def build_kit_prompt_pack(style: dict[str, Any], components: Iterable[dict[str, Any]]) -> dict[str, Any]:
    output_contract = style.get("output_contract", {})
    naming = output_contract.get("naming", "{style_id}_{slot_id}.png")
    style_bible = load_style_bible(style)
    prompts: list[dict[str, Any]] = []
    for component in components:
        component_id = str(component.get("id", ""))
        kind = str(component.get("kind", "panel"))
        for state in component.get("states", ["normal"]):
            asset_id = f"{component_id}_{state}"
            component_rule = style_bible.get("component_rules", {}).get(kind, "")
            state_prompt = state_prompt_fragment(str(state))
            prompts.append(
                {
                    "slot_id": asset_id,
                    "asset_id": asset_id,
                    "component_id": component_id,
                    "state": state,
                    "kind": kind,
                    "label": f"{component.get('label', component_id)} / {state}",
                    "prompt": ", ".join(
                        part
                        for part in [
                            style.get("style_prompt", ""),
                            component_rule,
                            component.get("prompt", ""),
                            state_prompt,
                            "transparent background, one isolated reusable UI component, generous padding",
                        ]
                        if part
                    ),
                    "negative_prompt": ", ".join(
                        part
                        for part in [
                            style.get("negative_prompt", ""),
                            "complete screen mockup, multiple UI elements, baked labels, tiny fake letters",
                        ]
                        if part
                    ),
                    "output_name": naming.replace("{style_id}", str(style.get("id", ""))).replace(
                        "{slot_id}", asset_id
                    ),
                    "nine_patch": component.get("nine_patch", [0, 0, 0, 0]),
                }
            )
    return {
        "schema_version": 1,
        "style_id": style.get("id", ""),
        "style_label": style.get("label", ""),
        "reference_mode": style.get("reference_mode", "text_style"),
        "reference_image": style.get("reference_image", ""),
        "output_contract": output_contract,
        "style_bible": style_bible,
        "mode": "ui_kit",
        "prompts": prompts,
    }


def state_prompt_fragment(state: str) -> str:
    fragments = {
        "normal": "normal default state",
        "hover": "hover state, slightly brighter highlight, same silhouette as normal",
        "pressed": "pressed state, slightly darker inset feel, same silhouette as normal",
        "disabled": "disabled state, muted low contrast, same silhouette as normal",
        "active": "active selected tab state, clear emphasis",
        "inactive": "inactive tab state, subdued but readable",
        "selected": "selected icon frame state, visible highlight",
        "featured": "featured portrait frame state, premium accent",
        "frame": "bar frame only with readable empty track",
        "fill": "bar fill strip only, horizontally tileable",
    }
    return fragments.get(state, f"{state} state")


def load_style_bible(style: dict[str, Any]) -> dict[str, Any]:
    style_path = resolve_resource_path(f"res://ui_pipeline/styles/{style.get('id', '')}/style_bible.json")
    if style_path.exists():
        return read_json(style_path)
    return {
        "schema_version": 1,
        "style_id": style.get("id", ""),
        "palette": [],
        "motifs": [],
        "materials": [],
        "layout_language": [],
        "component_rules": {},
        "avoid": [],
    }


def compile_skin(
    style: dict[str, Any],
    skin: dict[str, Any],
    components: Iterable[dict[str, Any]],
) -> dict[str, Any]:
    component_catalog = {component["id"]: component for component in components}
    skin_components = skin.get("components", {})
    compiled_components: dict[str, Any] = {}

    for component_id, component in component_catalog.items():
        source_component = skin_components.get(component_id, {})
        states: dict[str, Any] = {}
        for state in component.get("states", ["normal"]):
            state_data = source_component.get("states", {}).get(state, {})
            if not state_data and state != "normal":
                state_data = source_component.get("states", {}).get("normal", {})
            if not state_data:
                slot_fallback = skin.get("slots", {}).get(component_id, {})
                state_data = {"image": slot_fallback.get("image", ""), "tint": slot_fallback.get("color", "")}
            states[state] = {
                "image": state_data.get("image", ""),
                "tint": state_data.get("tint", ""),
            }
        compiled_components[component_id] = {
            "kind": component.get("kind", "panel"),
            "nine_patch": source_component.get("nine_patch", component.get("nine_patch", [0, 0, 0, 0])),
            "states": states,
        }

    return {
        "schema_version": 1,
        "style_id": style.get("id", ""),
        "label": skin.get("label", style.get("label", "")),
        "font_color": skin.get("font_color", "#FFFFFF"),
        "muted_color": skin.get("muted_color", "#AAAAAA"),
        "components": compiled_components,
    }


def render_prompt_pack_markdown(prompt_pack: dict[str, Any]) -> str:
    lines = [
        f"# {prompt_pack['style_label']} Prompt Pack",
        "",
        f"Style ID: `{prompt_pack['style_id']}`",
        f"Mode: `{prompt_pack.get('mode', 'legacy_slots')}`",
        "",
    ]
    for prompt in prompt_pack["prompts"]:
        lines.extend(
            [
                f"## {prompt['label']}",
                "",
                f"Output: `{prompt['output_name']}`",
                "",
                "Prompt:",
                "",
                prompt["prompt"],
                "",
                "Negative:",
                "",
                prompt["negative_prompt"],
                "",
            ]
        )
    return "\n".join(lines)


def _load_index_array(path: Path, key: str, errors: list[str] | None) -> list[dict[str, Any]]:
    payload = read_json(path, errors)
    values = payload.get(key, []) if isinstance(payload, dict) else []
    if not isinstance(values, list):
        if errors is not None:
            errors.append(f"{relative(path)} field '{key}' must be an array.")
        return []
    return [value for value in values if isinstance(value, dict)]


def _validate_style(style_id: str, style: dict[str, Any], errors: list[str]) -> None:
    if not style:
        return
    if style.get("id") != style_id:
        errors.append(f"Style id mismatch: index {style_id}, file {style.get('id')}")
    _required_string(style, "style_prompt", f"style {style_id}", errors)
    reference_image = style.get("reference_image", "")
    if isinstance(reference_image, str) and reference_image:
        if not resolve_resource_path(reference_image).exists():
            errors.append(f"Style {style_id} reference image does not exist: {reference_image}")
    output_contract = style.get("output_contract")
    if not isinstance(output_contract, dict):
        errors.append(f"Style {style_id} missing output_contract object.")
    style_bible_path = resolve_resource_path(f"res://ui_pipeline/styles/{style_id}/style_bible.json")
    if style_bible_path.exists():
        style_bible = read_json(style_bible_path, errors)
        if style_bible.get("style_id") != style_id:
            errors.append(f"Style bible id mismatch: style {style_id}, bible {style_bible.get('style_id')}")


def _validate_skin(
    style_id: str,
    skin: dict[str, Any],
    slot_ids: set[Any],
    component_ids: set[Any],
    errors: list[str],
    warnings: list[str],
) -> None:
    slots = skin.get("slots", {}) if isinstance(skin, dict) else {}
    if not isinstance(slots, dict):
        errors.append(f"Skin {style_id} field 'slots' must be an object.")
        return
    for slot_id, slot_style in slots.items():
        if slot_id not in slot_ids:
            warnings.append(f"Skin {style_id} references unknown slot: {slot_id}")
        if not isinstance(slot_style, dict):
            errors.append(f"Skin {style_id} slot {slot_id} must be an object.")
            continue
        image_path = slot_style.get("image")
        if isinstance(image_path, str) and image_path and not resolve_resource_path(image_path).exists():
            errors.append(f"Skin {style_id} image does not exist: {image_path}")

    components = skin.get("components", {})
    if components and not isinstance(components, dict):
        errors.append(f"Skin {style_id} field 'components' must be an object.")
        return
    for component_id, component_skin in components.items():
        if component_id not in component_ids:
            warnings.append(f"Skin {style_id} references unknown component: {component_id}")
        if not isinstance(component_skin, dict):
            errors.append(f"Skin {style_id} component {component_id} must be an object.")
            continue
        states = component_skin.get("states", {})
        if not isinstance(states, dict):
            errors.append(f"Skin {style_id} component {component_id} states must be an object.")
            continue
        for state, state_data in states.items():
            if not isinstance(state_data, dict):
                errors.append(f"Skin {style_id} component {component_id}.{state} must be an object.")
                continue
            image_path = state_data.get("image")
            if isinstance(image_path, str) and image_path and not resolve_resource_path(image_path).exists():
                errors.append(f"Skin {style_id} component image does not exist: {image_path}")


def _validate_asset_library(
    library_id: str,
    library: dict[str, Any],
    errors: list[str],
) -> None:
    if not library:
        return
    if library.get("id") != library_id:
        errors.append(f"Asset library id mismatch: index {library_id}, file {library.get('id')}")
    groups = library.get("libraries", [])
    if not isinstance(groups, list):
        errors.append(f"Asset library {library_id} field 'libraries' must be an array.")
        return
    seen_groups: set[str] = set()
    for group in groups:
        if not isinstance(group, dict):
            errors.append(f"Asset library {library_id} has a non-object group.")
            continue
        group_id = _required_string(group, "id", f"asset library {library_id} group", errors)
        _check_duplicate(group_id, seen_groups, f"asset library {library_id} group", errors)
        assets = group.get("assets", [])
        if not isinstance(assets, list):
            errors.append(f"Asset library {library_id} group {group_id} field 'assets' must be an array.")
            continue
        seen_assets: set[str] = set()
        for asset in assets:
            if not isinstance(asset, dict):
                errors.append(f"Asset library {library_id} group {group_id} has a non-object asset.")
                continue
            asset_id = _required_string(asset, "id", f"asset library {library_id} group {group_id} asset", errors)
            _check_duplicate(asset_id, seen_assets, f"asset library {library_id} group {group_id} asset", errors)
            asset_path = _required_string(asset, "path", f"asset library {library_id} asset {asset_id}", errors)
            if asset_path and not resolve_resource_path(asset_path).exists():
                errors.append(f"Asset library {library_id} asset does not exist: {asset_path}")


def _validate_template(
    template_id: str,
    template: dict[str, Any],
    slot_ids: set[Any],
    component_ids: set[Any],
    errors: list[str],
) -> None:
    if not template:
        return
    if template.get("id") != template_id:
        errors.append(f"Template id mismatch: index {template_id}, file {template.get('id')}")
    nodes = template.get("nodes")
    if not isinstance(nodes, list):
        errors.append(f"Template {template_id} field 'nodes' must be an array.")
        return
    for node in nodes:
        if not isinstance(node, dict):
            errors.append(f"Template {template_id} has a non-object node.")
            continue
        node_id = node.get("id", "<missing>")
        slot_id = node.get("slot")
        component_id = node.get("component")
        if slot_id not in slot_ids:
            errors.append(f"Template {template_id} node {node_id} references unknown slot: {slot_id}")
        if component_id is not None and component_id not in component_ids:
            errors.append(f"Template {template_id} node {node_id} references unknown component: {component_id}")
        rect = node.get("rect")
        if not isinstance(rect, list) or len(rect) != 4:
            errors.append(f"Template {template_id} node {node_id} rect must have four values.")


def _validate_components(components: list[dict[str, Any]], errors: list[str]) -> None:
    seen: set[str] = set()
    for component in components:
        component_id = _required_string(component, "id", "component", errors)
        _check_duplicate(component_id, seen, "component", errors)
        states = component.get("states", [])
        if not isinstance(states, list) or not states:
            errors.append(f"Component {component_id} must declare at least one state.")
        nine_patch = component.get("nine_patch", [])
        if not isinstance(nine_patch, list) or len(nine_patch) != 4:
            errors.append(f"Component {component_id} nine_patch must have four values.")


def _required_string(
    payload: dict[str, Any],
    field: str,
    label: str,
    errors: list[str],
) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value:
        errors.append(f"{label} missing string field '{field}'.")
        return ""
    return value


def _check_duplicate(value: str, seen: set[str], label: str, errors: list[str]) -> None:
    if not value:
        return
    if value in seen:
        errors.append(f"Duplicate {label} id: {value}")
    seen.add(value)


def read_json(path: Path, errors: list[str] | None = None) -> dict[str, Any]:
    if not path.exists():
        if errors is not None:
            errors.append(f"JSON file does not exist: {relative(path)}")
        return {}
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        if errors is not None:
            errors.append(f"Invalid JSON in {relative(path)}: {exc}")
        return {}
    if isinstance(parsed, dict):
        return parsed
    if errors is not None:
        errors.append(f"JSON file must contain an object: {relative(path)}")
    return {}


def resolve_resource_path(path: str) -> Path:
    if path.startswith("res://"):
        return GAME_ROOT / path.removeprefix("res://")
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
