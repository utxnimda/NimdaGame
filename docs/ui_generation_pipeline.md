# UI Generation Pipeline

UI Forge standardizes this flow:

```text
style or reference image
  -> AI prompt pack
  -> generated UI art slots
  -> layout template
  -> one-click skin preview
  -> saved custom template
```

The first implementation is a Godot runtime demo plus Python tooling. It is designed to work even before a specific AI image provider is chosen.

UI Forge is managed as a runtime plugin:

```text
game/plugins/ui_forge_tool/plugin.json
```

Enable or disable it through:

```text
game/plugins/enabled_plugins.json
```

## Data Layout

```text
game/ui_pipeline/
  asset_slots.json                  Required UI image slots
  styles/index.json                 Style registry
  styles/<style_id>/style.json      AI style prompt and output contract
  styles/<style_id>/skin.json       Slot-to-image/color mapping
  templates/index.json              Template registry
  templates/base/*.json             Versioned base layouts
  generated/<style_id>/*            Generated or placeholder UI art
```

User-saved templates are written to:

```text
user://ui_templates/
```

Prompt packs from the Godot demo are written to:

```text
user://ui_pipeline/
```

Prompt packs from the Python tool are written to:

```text
dist/ui_pipeline/<style_id>/
```

## AI Provider Setup

The default provider is OpenAI Images:

```text
tools/ai_providers/openai_images.json
```

Local token setup:

```powershell
copy .env.example .env
```

Then edit `.env`:

```text
OPENAI_API_KEY=your_api_key_here
NIMDAGAME_AI_PROVIDER=openai_images
NIMDAGAME_OPENAI_IMAGE_MODEL=gpt-image-1
```

`.env` is ignored by Git.

Check provider readiness:

```powershell
python tools/mygame_tools/ui_ai_provider.py check
```

The OpenAI Image API is used for single-prompt image generation. The provider config is model-driven so the default model can be changed without code edits.

## Step 1: Generate UI Art With AI

Define a style:

```text
game/ui_pipeline/styles/<style_id>/style.json
```

The style contains:

- `style_prompt`
- `negative_prompt`
- optional reference-image metadata
- output format and naming convention

Generate a prompt pack:

```powershell
python tools/mygame_tools/ui_pipeline.py prompt-pack --style neon_arcade
```

The output is provider-neutral JSON and Markdown. Feed each prompt to the chosen AI image tool and place the generated files into:

```text
game/ui_pipeline/generated/<style_id>/
```

Then map those files in:

```text
game/ui_pipeline/styles/<style_id>/skin.json
```

Generate with the OpenAI provider:

```powershell
python tools/mygame_tools/ui_ai_provider.py dry-run --style neon_arcade
python tools/mygame_tools/ui_ai_provider.py generate --style neon_arcade --slot button_primary
python tools/mygame_tools/ui_ai_provider.py generate --style neon_arcade --write-skin
```

PowerShell wrapper:

```powershell
scripts/ui_generate.ps1 -DryRun -Style neon_arcade
scripts/ui_generate.ps1 -Style neon_arcade -Slot button_primary
scripts/ui_generate.ps1 -Style neon_arcade -WriteSkin
```

Generated files are written to:

```text
game/ui_pipeline/generated/<style_id>/ai/
```

## Step 2: Build Or Save Layout Templates

Base templates live in:

```text
game/ui_pipeline/templates/base/
```

Each template is JSON:

```json
{
  "schema_version": 1,
  "id": "rpg_battle_hud",
  "label": "RPG Battle HUD",
  "canvas_size": [960, 540],
  "nodes": [
    {
      "id": "attack_button",
      "type": "button",
      "slot": "button_primary",
      "rect": [466, 418, 142, 42],
      "text": "Attack"
    }
  ]
}
```

In UI Forge, drag nodes on the preview canvas and save a custom copy. The custom save path uses Godot `user://`, so it is safe for local experiments and packaged builds.

## Step 3: Apply Generated Art

`skin.json` maps template slots to generated UI art:

```json
{
  "slots": {
    "button_primary": {
      "image": "res://ui_pipeline/generated/neon_arcade/button_primary.svg",
      "color": "#1F6570",
      "border": "#E1B44C"
    }
  }
}
```

UI Forge loads the selected template, loads the selected skin, and replaces each slot with the mapped image. If an image is missing, it falls back to the color and border values.

## Godot Demo

Open:

```text
Systems Lab / UI Forge
```

The demo supports:

- style selection
- template selection
- prompt-pack save
- drag-to-reposition template nodes
- one-click skin application
- custom template save
- plugin-managed Demo Hub entry

## Tooling

```powershell
python tools/mygame_tools/ui_pipeline.py list
python tools/mygame_tools/ui_pipeline.py validate
python tools/mygame_tools/ui_pipeline.py prompt-pack --style neon_arcade
python tools/mygame_tools/ui_ai_provider.py check
python tools/mygame_tools/ui_ai_provider.py dry-run --style neon_arcade
```

The release pipeline also runs UI pipeline validation:

```powershell
python tools/mygame_tools/release_pipeline.py check
```

## Provider Adapter Rule

AI image providers should be wrapped outside Godot first. The stable contract is the prompt pack:

```text
prompt_pack.json -> provider adapter -> generated UI images -> skin.json
```

This keeps API keys, rate limits, and provider-specific retries out of the shipped game.

The Godot UI Forge scene consumes generated assets through `skin.json`; it does not need to know which AI provider produced them.
