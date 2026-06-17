# Servers

This directory is intentionally not structured yet.

Server architecture will be decided after evaluating existing server frameworks and migration options. Until then, keep production server assumptions out of the repository structure.

Long-term constraints still apply:

- Shared deterministic gameplay code should live in `core/`.
- Client/server message contracts should live in `protocol/`.
- Server-specific code will live somewhere under `servers/` after the server stack is chosen.
- The preferred implementation direction remains C++ services plus an embedded scripting layer, but exact service boundaries are not fixed yet.
