# Core Bridge Addon

`core_bridge.gdextension.example` is a disabled GDExtension descriptor.

Keep it disabled until the matching native libraries exist under `clients/godot/addons/core_bridge/bin/`. When the bridge build is ready, copy or generate it as:

```text
clients/godot/addons/core_bridge/core_bridge.gdextension
```

Godot auto-loads `.gdextension` files. Keeping the scaffold as `.example` prevents startup errors before the native bridge is built.
