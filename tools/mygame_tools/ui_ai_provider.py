"""Generate UI art from UI Forge prompt packs through AI image providers."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    from mygame_tools.ui_pipeline import (
        ASSET_SLOTS_PATH,
        GAME_ROOT,
        REPO_ROOT,
        build_prompt_pack,
        load_styles,
        read_json,
        resolve_resource_path,
    )
except ModuleNotFoundError:
    from ui_pipeline import (
        ASSET_SLOTS_PATH,
        GAME_ROOT,
        REPO_ROOT,
        build_prompt_pack,
        load_styles,
        read_json,
        resolve_resource_path,
    )


DEFAULT_PROVIDER_CONFIG = REPO_ROOT / "tools" / "ai_providers" / "openai_images.json"
ENV_FILE = REPO_ROOT / ".env"


@dataclass(frozen=True)
class ProviderConfig:
    id: str
    label: str
    provider: str
    endpoint: str
    edit_endpoint: str
    api_key_env: str
    model_env: str
    default_model: str
    default_size: str
    default_quality: str
    default_output_format: str
    default_background: str
    timeout_seconds: int


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider-config", default=str(DEFAULT_PROVIDER_CONFIG))
    parser.add_argument("--env-file", default=str(ENV_FILE))

    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser("check", help="Check provider configuration and token presence.")
    check.set_defaults(func=cmd_check)

    dry_run = subparsers.add_parser("dry-run", help="Print requests that would be sent.")
    _add_generate_args(dry_run)
    dry_run.set_defaults(func=cmd_dry_run)

    generate = subparsers.add_parser("generate", help="Generate UI art from a style prompt pack.")
    _add_generate_args(generate)
    generate.add_argument("--write-skin", action="store_true", help="Update the style skin.json with generated images.")
    generate.set_defaults(func=cmd_generate)

    args = parser.parse_args(argv)
    load_env_file(Path(args.env_file))
    provider = load_provider_config(Path(args.provider_config))
    return args.func(args, provider)


def _add_generate_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--style", default="neon_arcade")
    parser.add_argument("--slot", action="append", default=[], help="Generate only this slot id. Repeatable.")
    parser.add_argument("--output-root", default=str(GAME_ROOT / "ui_pipeline" / "generated"))
    parser.add_argument("--model", default=None)
    parser.add_argument("--size", default=None)
    parser.add_argument("--quality", default=None)
    parser.add_argument("--output-format", default=None)
    parser.add_argument("--background", default=None)
    parser.add_argument("--reference-image", default=None, help="Reference image path. Defaults to style.reference_image when present.")


def cmd_check(_args: argparse.Namespace, provider: ProviderConfig) -> int:
    api_key = os.environ.get(provider.api_key_env, "")
    print(f"Provider: {provider.label}")
    print(f"Endpoint: {provider.endpoint}")
    print(f"Model: {resolve_model(provider, None)}")
    print(f"Token env: {provider.api_key_env}")
    if not api_key:
        print(f"ERROR: {provider.api_key_env} is not set.")
        return 1
    print("AI provider configuration is ready.")
    return 0


def cmd_dry_run(args: argparse.Namespace, provider: ProviderConfig) -> int:
    prompt_pack = prompt_pack_for_style(args.style)
    prompts = select_prompts(prompt_pack, args.slot)
    print(f"Provider: {provider.label}")
    print(f"Model: {resolve_model(provider, args.model)}")
    print(f"Output root: {Path(args.output_root) / args.style / 'ai'}")
    for prompt in prompts:
        request = build_openai_image_request(provider, args, prompt)
        print("")
        print(f"Slot: {prompt['slot_id']}")
        print(json.dumps({k: v for k, v in request.items() if k != "prompt"}, indent=2))
        reference_image = resolve_reference_image(args, prompt_pack)
        if reference_image:
            print(f"Reference image: {relative(reference_image)}")
        print(f"Prompt: {prompt['prompt']}")
    return 0


def cmd_generate(args: argparse.Namespace, provider: ProviderConfig) -> int:
    api_key = os.environ.get(provider.api_key_env, "")
    if not api_key:
        print(f"ERROR: {provider.api_key_env} is not set. Copy .env.example to .env and fill it in.", file=sys.stderr)
        return 1

    prompt_pack = prompt_pack_for_style(args.style)
    prompts = select_prompts(prompt_pack, args.slot)
    output_dir = Path(args.output_root) / args.style / "ai"
    output_dir.mkdir(parents=True, exist_ok=True)
    reference_image = resolve_reference_image(args, prompt_pack)

    generated: dict[str, str] = {}
    for prompt in prompts:
        request_payload = build_openai_image_request(provider, args, prompt)
        print(f"Generating {prompt['slot_id']}...")
        if reference_image is not None:
            image_bytes = call_openai_image_edit(provider, api_key, request_payload, reference_image)
        else:
            image_bytes = call_openai_images(provider, api_key, request_payload)
        output_path = output_dir / prompt["output_name"]
        output_path.write_bytes(image_bytes)
        generated[prompt["slot_id"]] = resource_path(output_path)
        print(f"Wrote {relative(output_path)}")

    manifest_path = output_dir / "generation_manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "provider": provider.id,
                "model": resolve_model(provider, args.model),
                "style_id": args.style,
                "generated": generated,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Wrote {relative(manifest_path)}")

    if args.write_skin:
        update_skin(args.style, generated)
        print(f"Updated skin for style: {args.style}")

    return 0


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().lstrip("\ufeff")
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def load_provider_config(path: Path) -> ProviderConfig:
    raw = read_json(resolve_path(path))
    return ProviderConfig(
        id=str(raw.get("id", "openai_images")),
        label=str(raw.get("label", "OpenAI Images")),
        provider=str(raw.get("provider", "openai")),
        endpoint=str(raw.get("endpoint", "https://api.openai.com/v1/images/generations")),
        edit_endpoint=str(raw.get("edit_endpoint", "https://api.openai.com/v1/images/edits")),
        api_key_env=str(raw.get("api_key_env", "OPENAI_API_KEY")),
        model_env=str(raw.get("model_env", "NIMDAGAME_OPENAI_IMAGE_MODEL")),
        default_model=str(raw.get("default_model", "gpt-image-1")),
        default_size=str(raw.get("default_size", "1024x1024")),
        default_quality=str(raw.get("default_quality", "medium")),
        default_output_format=str(raw.get("default_output_format", "png")),
        default_background=str(raw.get("default_background", "transparent")),
        timeout_seconds=int(raw.get("timeout_seconds", 180)),
    )


def prompt_pack_for_style(style_id: str) -> dict[str, Any]:
    styles = {style["id"]: style for style in load_styles()}
    if style_id not in styles:
        raise SystemExit(f"Unknown style: {style_id}")
    style = read_json(resolve_resource_path(styles[style_id]["style_path"]))
    asset_slots = read_json(ASSET_SLOTS_PATH)["slots"]
    prompt_pack = build_prompt_pack(style, asset_slots)
    if "reference_image" in style:
        prompt_pack["reference_image"] = style["reference_image"]
    return prompt_pack


def resolve_reference_image(args: argparse.Namespace, prompt_pack: dict[str, Any]) -> Path | None:
    image_path = args.reference_image or prompt_pack.get("reference_image", "")
    if not image_path:
        return None
    resolved = resolve_resource_path(str(image_path))
    if not resolved.exists():
        raise SystemExit(f"Reference image does not exist: {image_path}")
    return resolved


def select_prompts(prompt_pack: dict[str, Any], requested_slots: Iterable[str]) -> list[dict[str, Any]]:
    prompts = list(prompt_pack["prompts"])
    requested = set(requested_slots)
    if not requested:
        return prompts

    selected = [prompt for prompt in prompts if prompt["slot_id"] in requested]
    missing = requested - {prompt["slot_id"] for prompt in selected}
    if missing:
        raise SystemExit(f"Unknown slot id: {', '.join(sorted(missing))}")
    return selected


def build_openai_image_request(
    provider: ProviderConfig,
    args: argparse.Namespace,
    prompt: dict[str, Any],
) -> dict[str, Any]:
    output_format = args.output_format or provider.default_output_format
    payload: dict[str, Any] = {
        "model": resolve_model(provider, args.model),
        "prompt": prompt["prompt"],
        "size": args.size or provider.default_size,
        "quality": args.quality or provider.default_quality,
        "output_format": output_format,
        "n": 1,
    }

    background = args.background if args.background is not None else provider.default_background
    if background:
        payload["background"] = background

    return payload


def resolve_model(provider: ProviderConfig, explicit_model: str | None) -> str:
    if explicit_model:
        return explicit_model
    env_model = os.environ.get(provider.model_env, "")
    if env_model:
        return env_model
    return provider.default_model


def call_openai_images(provider: ProviderConfig, api_key: str, payload: dict[str, Any]) -> bytes:
    request = urllib.request.Request(
        provider.endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=provider.timeout_seconds) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"OpenAI image request failed: HTTP {exc.code}\n{body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"OpenAI image request failed: {exc}") from exc

    parsed = json.loads(response_body)
    data = parsed.get("data", [])
    if not data or "b64_json" not in data[0]:
        raise SystemExit(f"OpenAI image response did not contain data[0].b64_json: {response_body}")
    return base64.b64decode(data[0]["b64_json"])


def call_openai_image_edit(
    provider: ProviderConfig,
    api_key: str,
    payload: dict[str, Any],
    image_path: Path,
) -> bytes:
    fields = {key: str(value) for key, value in payload.items() if key != "n"}
    fields["n"] = str(payload.get("n", 1))
    body, content_type = build_multipart_body(
        fields,
        file_field="image",
        file_path=image_path,
        mime_type=mime_type_for_path(image_path),
    )
    request = urllib.request.Request(
        provider.edit_endpoint,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": content_type,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=provider.timeout_seconds) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"OpenAI image edit request failed: HTTP {exc.code}\n{body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"OpenAI image edit request failed: {exc}") from exc

    parsed = json.loads(response_body)
    data = parsed.get("data", [])
    if not data or "b64_json" not in data[0]:
        raise SystemExit(f"OpenAI image edit response did not contain data[0].b64_json: {response_body}")
    return base64.b64decode(data[0]["b64_json"])


def build_multipart_body(
    fields: dict[str, str],
    file_field: str,
    file_path: Path,
    mime_type: str,
) -> tuple[bytes, str]:
    boundary = "----NimdaGameBoundary7MA4YWxkTrZu0gW"
    chunks: list[bytes] = []
    for key, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode("utf-8"),
                f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode("utf-8"),
                value.encode("utf-8"),
                b"\r\n",
            ]
        )

    chunks.extend(
        [
            f"--{boundary}\r\n".encode("utf-8"),
            f'Content-Disposition: form-data; name="{file_field}"; filename="{file_path.name}"\r\n'.encode("utf-8"),
            f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"),
            file_path.read_bytes(),
            b"\r\n",
            f"--{boundary}--\r\n".encode("utf-8"),
        ]
    )
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def mime_type_for_path(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if suffix == ".webp":
        return "image/webp"
    return "image/png"


def update_skin(style_id: str, generated: dict[str, str]) -> None:
    styles = {style["id"]: style for style in load_styles()}
    skin_path = resolve_resource_path(styles[style_id]["skin_path"])
    skin = read_json(skin_path)
    slots = skin.setdefault("slots", {})
    for slot_id, image_path in generated.items():
        slot = slots.setdefault(slot_id, {})
        slot["image"] = image_path
    skin_path.write_text(json.dumps(skin, indent=2, ensure_ascii=False), encoding="utf-8")


def resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def resource_path(path: Path) -> str:
    resolved = path.resolve()
    game_root = GAME_ROOT.resolve()
    try:
        return "res://" + str(resolved.relative_to(game_root)).replace("\\", "/")
    except ValueError:
        return str(path)


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
