# Release Pipeline

The release pipeline standardizes this order:

```text
check -> export -> package -> notes -> publish
```

The current pipeline is local-first. It can already plan, check repository layout, generate release notes, package exported builds, and prepare GitHub release commands. Real Godot export requires a local Godot executable and export presets.

## Commands

From the repository root:

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/release_pipeline.py check --strict
```

Run through the PowerShell wrapper:

```powershell
scripts/release.ps1 -Command plan
scripts/release.ps1 -Command check
```

## Godot Export Setup

Create export presets in the Godot editor:

1. Open `game/project.godot`.
2. Open `Project > Export`.
3. Add presets matching `release/release_targets.json`:
   - `Windows Desktop`
   - `Linux/X11`
   - `Web`
4. Save the project so Godot writes `game/export_presets.cfg`.

`game/export_presets.cfg` is ignored by default because future mobile presets may contain credentials. Commit a sanitized version only after reviewing it.

Set the Godot executable if it is not on `PATH`:

```powershell
$env:GODOT_BIN = "C:\Tools\Godot\Godot_v4.6-stable_win64_console.exe"
```

## Export

```powershell
python tools/mygame_tools/release_pipeline.py export windows --version 0.1.0
python tools/mygame_tools/release_pipeline.py export windows web --version 0.1.0
python tools/mygame_tools/release_pipeline.py export --version 0.1.0
```

No target means all configured targets.

## Package

```powershell
python tools/mygame_tools/release_pipeline.py package windows --version 0.1.0
python tools/mygame_tools/release_pipeline.py package --version 0.1.0
```

Packages are written under `dist/packages/`.

## Release Notes

```powershell
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

Release notes are written to:

```text
dist/releases/0.1.0/release-notes.md
```

## Publish

Dry-run the GitHub release command:

```powershell
python tools/mygame_tools/release_pipeline.py publish --version 0.1.0
```

Execute it after reviewing the generated command:

```powershell
python tools/mygame_tools/release_pipeline.py publish --version 0.1.0 --execute
```

Publishing requires the GitHub CLI `gh` to be installed and authenticated.
