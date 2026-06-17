# Clients

Client implementations live here.

```text
clients/
  godot/      Current Godot client project.
  native/     Reserved for a future native C++ client.
  web/        Reserved for a future web client.
```

All clients should depend on shared gameplay code through `core/` and shared message definitions through `protocol/`. Client-specific presentation, input, audio, UI, and platform integration stay inside each client package.
