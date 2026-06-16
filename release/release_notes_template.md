# NimdaGame {version}

## Demo Scope

- Turn RPG demo hub entry
- ARPG / survivor demo hub entry
- Tactics demo hub entry
- Systems Lab entry for tower defense, idle, cards, roguelite rewards, and meta progression

## Build Artifacts

{artifacts}

## Smoke Checks

- Open the exported build.
- Confirm all four demo categories can be selected.
- Confirm text and drawings are visible at the default window size.
- Confirm the package contains no source-only build directories.

## Known Gaps

- C++ GDExtension bridge is still scaffolded.
- Demo interactions are visual smoke tests, not full gameplay loops yet.
- Export presets must be created locally in Godot before running real exports.
