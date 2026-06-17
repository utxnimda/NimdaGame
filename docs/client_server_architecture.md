# Client And Server Architecture

NimdaGame uses a monorepo so clients, servers, shared C++ gameplay code, protocol schemas, and data schemas can evolve in one commit.

## Recommendation

Use one repository with explicit package boundaries:

```text
clients/       Client implementations such as Godot, native C++, or web.
servers/       Server implementations and server-side scripts.
core/          Shared C++ gameplay library used by clients, servers, tests, and tools.
protocol/      Client/server message schemas and generated bindings.
data/          Shared and genre-specific authored config.
tools/         Build, validation, generation, simulation, and release tooling.
release/       Release target configuration.
```

This is preferable to splitting the server into a separate repository at the current stage because shared C++ gameplay code and protocol schemas will change frequently. A monorepo keeps client, server, protocol, and config versions aligned.

## Shared C++ Core

`core/` owns deterministic, portable gameplay logic:

- IDs, RNG, math, events, and save-state primitives.
- Combat, unit, skill, status, grid, economy, and progression modules.
- Genre orchestration that must run identically on client and server.
- Script-facing APIs that can be bound to server Lua or future editor tooling.

The core must not depend on Godot or server transport frameworks.

## Clients

`clients/godot/` is the current Godot client. Future clients should be added as peers:

```text
clients/native/
clients/web/
```

Clients own presentation, input, audio, UI, local prediction, and platform integration. They should consume shared gameplay and protocol code through stable adapters.

## Servers

`servers/` is intentionally not structured yet. The final server layout will be chosen after evaluating existing server frameworks and migration options.

```text
servers/
  README.md
```

Recommended runtime direction:

```text
C++ authoritative services
+ embedded Lua scripts
+ shared core C++ library
```

Use Python for tooling, not as the production server runtime.

Do not commit fixed service boundaries such as gateway, matchmaker, admin API, or game server until the server stack is selected.

## Server Options

### Option A: Custom C++ Services + Lua

Best fit for this repository.

- Maximum control over deterministic simulation and performance.
- Directly links `core/`.
- Lua can host hot-reloadable rules, AI, events, and content scripting.
- Requires building networking, persistence, observability, and operations discipline.

### Option B: Nakama + C++ Core Adapter

Useful when account, storage, matchmaking, and social systems are needed early.

- Faster backend feature coverage.
- Authoritative match logic can call into shared C++ through an adapter if needed.
- Some gameplay architecture must fit Nakama's runtime model.

### Option C: Godot Headless Dedicated Server

Useful for rapid multiplayer prototyping if the Godot client remains primary.

- Fast iteration with shared scene/runtime concepts.
- Less ideal if the long-term server should be independent C++ plus scripts.
- Still can use `core/`, but avoid putting final server rules in Godot scripts.

### Option D: Kubernetes + Agones Later

Useful after the project needs fleet orchestration for many authoritative game server instances.

- Strong scaling and allocation model.
- Higher operational complexity.
- Not recommended as the first server deployment target.
