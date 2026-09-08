# Repository Layout

This repository is a monorepo for clients, servers, shared C++ gameplay logic, protocol schemas, authored data, tooling, and release config.

The goal is to keep client, server, protocol, data, and shared gameplay versions aligned in one commit.

## Current Snapshot

```text
NimdaGame/
  clients/
    godot/
      project.godot
      app/
      common/
      shared_assets/
      genres/
      plugins/
      addons/
        nimda_rpg_editor/
      data/generated/
    native/
    web/
  servers/
    README.md
  core/
    common/
    modules/
    genres/
  protocol/
    schemas/
    generated/
    docs/
  bindings/
  data/
    common/
    genres/
    schemas/
  tools/
  docs/
  release/
  scripts/
  dist/
  third_party/
```

## Clients

```text
clients/
  godot/      Current Godot client project.
  native/     Reserved for a future native C++ client.
  web/        Reserved for a future web client.
```

Clients own presentation, input, audio, UI, local prediction, platform integrations, and client-only tooling.

The Godot client uses its own project root:

```text
clients/godot/project.godot
clients/godot/app/scenes/main.tscn
```

Godot `res://` paths are relative to `clients/godot/`, not the repository root.

The Godot editor extension lives at:

```text
clients/godot/addons/nimda_rpg_editor/
```

## Servers

`servers/` is intentionally left as a placeholder. The final server layout will be chosen after evaluating existing server frameworks and migration options.

The preferred implementation direction remains C++ services plus an embedded scripting layer. Lua is the default recommendation for runtime scripting. Python remains a development-time tooling language.

Do not add fixed service boundaries such as gateway, matchmaker, admin API, or game server until the server framework decision is made.

## Shared C++ Core

```text
core/
  common/                IDs, RNG, events, save model, math helpers
  modules/               Reusable systems: battle, unit, skill, status, grid, economy
  genres/
    turn_rpg/
    survivor_arpg/
    tactics/
    tower_defense/
    idle/
```

Reusable gameplay primitives should go under `core/modules/`. Genre orchestration and rule sequencing that must be shared across clients and servers should go under `core/genres/<genre>/`.

`core/` must not depend on Godot or server transport frameworks.

## Protocol

```text
protocol/
  schemas/      Source protocol schemas.
  generated/    Generated protocol bindings.
  docs/         Compatibility policy and protocol notes.
```

Protocol ownership stays outside individual clients and servers so all implementations share one message version.

## Data

```text
data/
  common/                Shared YAML source data
  genres/
    turn_rpg/
    survivor_arpg/
    tactics/
    tower_defense/
    idle/
  schemas/
```

Shared data should be small and intentional. If a config carries genre assumptions, keep it under that genre.

Generated runtime data for the Godot client lives under:

```text
clients/godot/data/generated/
```

Future clients and servers may have their own generated output directories.

## Tools

```text
tools/
  mygame_tools/
    validate_config.py
    generate_godot_data.py
    rpg_editor_data.py
    simulate_battle.py
    balance_report.py
    validate_plugins.py
    release_pipeline.py
```

Tools should read source data from `data/`, protocol definitions from `protocol/`, shared gameplay code from `core/`, and write generated output to the owning package.

## Release And Deploy

```text
release/       Release target config and release notes templates.
dist/          Local build, package, and release output.
```

`release_pipeline.py` currently targets the Godot client. Server build and deployment automation should be added separately once the server runtime stack is finalized.

## Migration Rule

When adding a new feature, choose the narrowest owner:

1. Put client-specific behavior under the owning client package.
2. Put server-specific behavior under `servers/`.
3. Put deterministic gameplay logic shared by client and server under `core/`.
4. Put wire contracts under `protocol/`.
5. Move authored config to `data/common/` only after more than one package needs it.
