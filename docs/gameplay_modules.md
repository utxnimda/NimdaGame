# Gameplay Modules

This document lists the intended reusable gameplay modules.

## Unit Module

Represents actors such as heroes, monsters, towers, summons, projectiles with health, and other combat entities.

Typical data:

- ID and tags
- Base stats
- Growth rules
- Team or faction
- Skills
- Passive effects
- Collision or footprint information

## Skill Module

Represents active and passive abilities.

Skill effects should be data-driven where possible:

- Damage
- Heal
- Shield
- Status apply or remove
- Summon
- Move
- Spawn projectile
- Modify economy value

## Status Module

Represents buffs, debuffs, and state markers.

Examples:

- Burn
- Poison
- Stun
- Slow
- Taunt
- Damage amplification
- Temporary stat change

## Battle Module

Owns combat flow. It should support both turn-based and real-time modes through different controllers over shared primitives.

Code owner:

```text
core/modules/battle/
```

Examples:

- Turn queue
- Cooldown ticking
- Command resolution
- Target selection
- Damage calculation
- Event emission

## Grid Module

Supports tactics and tower defense games.

Responsibilities:

- Cell coordinates
- Terrain flags
- Occupancy
- Range queries
- Pathfinding
- Area of effect selection

## Economy Module

Supports incremental games, upgrades, drops, tower defense income, and RPG progression.

Responsibilities:

- Currencies
- Upgrade costs
- Reward formulas
- Offline progress
- Scaling curves

## Save Module

Stores player-owned state separately from static config.

Examples:

- Owned units
- Unit levels
- Unlocked content
- Inventory
- Currency balances
- Stage progress
- Settings

## RNG Module

Provides deterministic random numbers for simulation.

All gameplay randomness should flow through this module, not through Godot or platform random APIs.
