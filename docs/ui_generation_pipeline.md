# UI Generation Pipeline

UI Forge standardizes this flow:

```text
style or reference image
  -> style bible
  -> component catalog
  -> UI kit prompt pack
  -> generated component/state art
  -> layout template
  -> one-click skin preview or compiled skin
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
  asset_slots.json                  Legacy required UI image slots
  component_catalog.json            Canonical reusable UI components and states
  styles/index.json                 Style registry
  styles/<style_id>/style.json      AI style prompt and output contract
  styles/<style_id>/style_bible.json Palette, motifs, materials, and component rules
  styles/<style_id>/skin.json       Component/state skin plus legacy slot fallback
  templates/index.json              Template registry
  templates/base/*.json             Versioned base layouts
  compiled/<style_id>/*             Normalized UI kit skins
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

Provider configs live in:

```text
tools/ai_providers/openai_images.json
tools/ai_providers/gemini_images.json
```

Local token setup:

```powershell
copy .env.example .env
```

Then edit `.env`:

```text
OPENAI_API_KEY=
GEMINI_API_KEY=your_gemini_api_key_here
NIMDAGAME_AI_PROVIDER=gemini_images
NIMDAGAME_OPENAI_IMAGE_MODEL=gpt-image-1
NIMDAGAME_GEMINI_IMAGE_MODEL=gemini-3.1-flash-image
```

`.env` is ignored by Git.

Check provider readiness:

```powershell
python tools/mygame_tools/ui_ai_provider.py check
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images check
python tools/mygame_tools/ui_ai_provider.py --provider openai_images check
```

Gemini is the default local provider in `.env.example`. The Gemini adapter uses the Gemini API `generateContent` image endpoint with `gemini-3.1-flash-image` by default. OpenAI Images remains available through `--provider openai_images` or `NIMDAGAME_AI_PROVIDER=openai_images`.

## Step 1: Define The UI Kit Contract

`component_catalog.json` is the stable contract for AI generation and runtime usage. Each component declares:

- `id`, for example `button_primary`
- `kind`, for example `button`, `panel`, `bar`, `icon`, or `decor`
- required visual states, for example `normal`, `hover`, `pressed`, `disabled`
- `nine_patch` margins for later stretch-safe rendering
- a component-specific prompt fragment

This is what prevents AI generation from becoming "one picture with changed colors". The pipeline asks for concrete reusable pieces and states.

## Step 2: Describe The Style

Define a style:

```text
game/ui_pipeline/styles/<style_id>/style.json
```

The style contains:

- `style_prompt`
- `negative_prompt`
- optional reference-image metadata
- output format and naming convention

For custom styles, also add:

```text
game/ui_pipeline/styles/<style_id>/style_bible.json
```

The style bible breaks the reference image into reusable rules:

- palette
- motifs
- materials
- layout language
- component rules
- avoid list

Generate a prompt pack:

```powershell
python tools/mygame_tools/ui_pipeline.py prompt-pack --style neon_arcade
```

By default this creates a component UI Kit prompt pack. Use `--legacy-slots` only when you need the old slot-based prompts.

Inspect the component/state plan:

```powershell
python tools/mygame_tools/ui_pipeline.py kit-plan --style megami_magazine
```

The output is provider-neutral JSON and Markdown. Feed each prompt to the chosen AI image tool and place the generated files into:

```text
game/ui_pipeline/generated/<style_id>/
```

Then map those files in:

```text
game/ui_pipeline/styles/<style_id>/skin.json
```

Generate with the configured provider:

```powershell
python tools/mygame_tools/ui_ai_provider.py dry-run --style neon_arcade
python tools/mygame_tools/ui_ai_provider.py generate --style neon_arcade --slot button_primary
python tools/mygame_tools/ui_ai_provider.py generate --style neon_arcade --write-skin
```

Generate with Gemini explicitly:

```powershell
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images dry-run --style megami_magazine --slot button_primary
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images generate --style megami_magazine --slot button_primary.normal --write-skin
```

Generate with OpenAI explicitly:

```powershell
python tools/mygame_tools/ui_ai_provider.py --provider openai_images dry-run --style megami_magazine --slot button_primary
```

`--slot button_primary` selects every state for that component. You can also target a single asset or state, for example:

```powershell
python tools/mygame_tools/ui_ai_provider.py dry-run --style megami_magazine --slot button_primary.hover
python tools/mygame_tools/ui_ai_provider.py dry-run --style megami_magazine --slot button_primary_hover
```

PowerShell wrapper:

```powershell
scripts/ui_generate.ps1 -DryRun -Provider gemini_images -Style neon_arcade
scripts/ui_generate.ps1 -Provider gemini_images -Style neon_arcade -Slot button_primary
scripts/ui_generate.ps1 -Provider gemini_images -Style neon_arcade -WriteSkin
```

Generated files are written to:

```text
game/ui_pipeline/generated/<style_id>/ai/
```

## Step 3: Build Or Save Layout Templates

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
      "component": "button_primary",
      "slot": "button_primary",
      "rect": [466, 418, 142, 42],
      "text": "Attack"
    }
  ]
}
```

`component` is preferred. `slot` remains as a compatibility fallback for older skins.

In UI Forge, drag nodes on the preview canvas and save a custom copy. The custom save path uses Godot `user://`, so it is safe for local experiments and packaged builds.

## Step 4: Apply Generated Art

`skin.json` maps template components and states to generated UI art:

```json
{
  "components": {
    "button_primary": {
      "kind": "button",
      "nine_patch": [30, 20, 30, 20],
      "states": {
        "normal": {
          "image": "res://ui_pipeline/generated/megami_magazine/ai/megami_button_primary_normal.png"
        },
        "hover": {
          "image": "res://ui_pipeline/generated/megami_magazine/ai/megami_button_primary_hover.png"
        }
      }
    }
  }
}
```

UI Forge loads the selected template, loads the selected skin, and replaces each component with the mapped image. If a component image is missing, it falls back to legacy slot color and border values.

Compile a normalized skin:

```powershell
python tools/mygame_tools/ui_pipeline.py compile-kit --style megami_magazine
```

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

## Current Reference Style Pack

The project includes a reference-image style pack:

```text
game/ui_pipeline/styles/megami_magazine/
game/ui_pipeline/references/megami_magazine_reference.jpg
game/ui_pipeline/templates/megami/
```

It contains:

- `Megami Battle HUD`
- `Megami Character Card`
- `Megami Main Menu`

Generate AI assets for this style after API billing is available:

```powershell
python tools/mygame_tools/ui_ai_provider.py dry-run --style megami_magazine
python tools/mygame_tools/ui_ai_provider.py dry-run --style megami_magazine --slot button_primary
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images generate --style megami_magazine --write-skin
```

## Tooling

```powershell
python tools/mygame_tools/ui_pipeline.py list
python tools/mygame_tools/ui_pipeline.py validate
python tools/mygame_tools/ui_pipeline.py kit-plan --style megami_magazine
python tools/mygame_tools/ui_pipeline.py prompt-pack --style megami_magazine
python tools/mygame_tools/ui_pipeline.py prompt-pack --style neon_arcade --legacy-slots
python tools/mygame_tools/ui_pipeline.py compile-kit --style megami_magazine
python tools/mygame_tools/ui_ai_provider.py check
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images check
python tools/mygame_tools/ui_ai_provider.py --provider gemini_images dry-run --style megami_magazine --slot button_primary
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
