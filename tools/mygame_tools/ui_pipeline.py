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
ASSET_SLOTS_PATH = GAME_ROOT / "ui_pipeline" / "asset_slots.json"


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
    prompt_cmd.set_defaults(func=cmd_prompt_pack)

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
    asset_slots = read_json(ASSET_SLOTS_PATH)["slots"]
    prompt_pack = build_prompt_pack(style, asset_slots)

    output_dir = Path(args.output) / args.style
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "prompt_pack.json"
    markdown_path = output_dir / "prompt_pack.md"
    json_path.write_text(json.dumps(prompt_pack, indent=2, ensure_ascii=False), encoding="utf-8")
    markdown_path.write_text(render_prompt_pack_markdown(prompt_pack), encoding="utf-8")

    print(f"Wrote {relative(json_path)}")
    print(f"Wrote {relative(markdown_path)}")
    return 0


def validate_ui_pipeline() -> ValidationResult:
    errors: list[str] = []
    warnings: list[str] = []

    styles = load_styles(errors)
    templates = load_templates(errors)
    asset_slots = load_asset_slots(errors)
    slot_ids = {slot.get("id") for slot in asset_slots if isinstance(slot, dict)}

    seen_styles: set[str] = set()
    for style_entry in styles:
        style_id = _required_string(style_entry, "id", "style index entry", errors)
        _check_duplicate(style_id, seen_styles, "style", errors)
        style_path = _required_string(style_entry, "style_path", f"style {style_id}", errors)
        skin_path = _required_string(style_entry, "skin_path", f"style {style_id}", errors)
        style = read_json(resolve_resource_path(style_path), errors)
        skin = read_json(resolve_resource_path(skin_path), errors)
        _validate_style(style_id, style, errors)
        _validate_skin(style_id, skin, slot_ids, errors, warnings)

    seen_templates: set[str] = set()
    for template_entry in templates:
        template_id = _required_string(template_entry, "id", "template index entry", errors)
        _check_duplicate(template_id, seen_templates, "template", errors)
        template_path = _required_string(template_entry, "path", f"template {template_id}", errors)
        template = read_json(resolve_resource_path(template_path), errors)
        _validate_template(template_id, template, slot_ids, errors)

    return ValidationResult(tuple(errors), tuple(warnings))


def load_styles(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(STYLE_INDEX_PATH, "styles", errors)


def load_templates(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(TEMPLATE_INDEX_PATH, "templates", errors)


def load_asset_slots(errors: list[str] | None = None) -> list[dict[str, Any]]:
    return _load_index_array(ASSET_SLOTS_PATH, "slots", errors)


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
        "output_contract": output_contract,
        "prompts": prompts,
    }


def render_prompt_pack_markdown(prompt_pack: dict[str, Any]) -> str:
    lines = [
        f"# {prompt_pack['style_label']} Prompt Pack",
        "",
        f"Style ID: `{prompt_pack['style_id']}`",
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
    output_contract = style.get("output_contract")
    if not isinstance(output_contract, dict):
        errors.append(f"Style {style_id} missing output_contract object.")


def _validate_skin(
    style_id: str,
    skin: dict[str, Any],
    slot_ids: set[Any],
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


def _validate_template(
    template_id: str,
    template: dict[str, Any],
    slot_ids: set[Any],
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
        if slot_id not in slot_ids:
            errors.append(f"Template {template_id} node {node_id} references unknown slot: {slot_id}")
        rect = node.get("rect")
        if not isinstance(rect, list) or len(rect) != 4:
            errors.append(f"Template {template_id} node {node_id} rect must have four values.")


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
