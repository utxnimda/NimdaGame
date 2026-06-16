# Release Checklist

## Before Export

- `main` is clean.
- YAML source data validates.
- Godot opens `game/project.godot`.
- All four demo categories load in the Demo Hub.
- Export presets exist in `game/export_presets.cfg`.
- Version number is chosen.

## Build

- Run the release pipeline check.
- Export each target from the same commit.
- Package artifacts from `dist/exports/`.
- Generate release notes.

## Smoke Test

- Launch Windows package if produced.
- Open Web package locally if produced.
- Confirm Demo Hub is visible.
- Select Turn RPG, ARPG / Survivor, Tactics, and Systems Lab.
- Confirm no missing script or asset errors appear.

## Publish

- Create or update the GitHub release.
- Upload package zip files.
- Attach release notes.
- Tag the release commit.
