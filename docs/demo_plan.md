# Demo Plan

The first demo is a centralized Demo Hub. It is intentionally small and asset-light so it can become the standard smoke test for build, package, and release automation.

## Categories

### 1. Turn RPG

Use this category for classic command-based RPG flow.

Representative systems:

- Party and enemy formation
- Command selection
- Turn queue
- Skill resolution
- Battle log
- Buff and debuff lifecycle

Release smoke value:

- Confirms generated config is bundled.
- Confirms deterministic combat hooks can be called.
- Confirms UI text and battle presentation export correctly.

### 2. ARPG / Survivor

Use this category for real-time lightweight RPGs and survivor-like games.

Representative systems:

- Movement
- Cooldowns
- Enemy waves
- Pickups
- Area queries
- Runtime spawn pressure

Release smoke value:

- Confirms input works after export.
- Confirms frame pacing is acceptable.
- Confirms timed update loops run outside the editor.

### 3. Tactics

Use this category for tactics and strategy RPG prototypes.

Representative systems:

- Grid coordinates
- Pathfinding
- Move range preview
- Attack range preview
- Terrain and occupancy
- Side turns

Release smoke value:

- Confirms grid rendering and layout.
- Confirms selection state works across scene reloads.
- Confirms tactical overlays have no missing assets.

### 4. Systems Lab

Use this category for gameplay that does not fit the first three groups but still shares framework systems.

Recommended subtypes:

- Tower defense
- Idle or incremental games
- Card-driven combat
- Roguelite reward drafts
- Equipment and meta progression
- Economy simulations

Release smoke value:

- Confirms save paths and config schemas are packaged correctly.
- Confirms economy math is deterministic.
- Confirms long-term progression data can migrate safely.

## Rule of Thumb

If a prototype mostly proves combat flow, put it in Turn RPG, ARPG, or Tactics. If it mostly proves economy, progression, content generation, rewards, or save migration, put it in Systems Lab.
