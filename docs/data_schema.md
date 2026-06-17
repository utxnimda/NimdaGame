# Data Schema

## Policy

Source data is authored as YAML. Runtime data is generated as JSON.

```text
data/common/**/*.yaml             Shared source data
data/genres/<genre>/**/*.yaml     Genre-specific source data
data/schemas/*.schema.json        Validation schemas
game/data/generated/*.json        Runtime data consumed by Godot
```

The C++ core and Godot runtime should not parse YAML directly.

## YAML Rules

To keep YAML predictable, use a small subset:

- No anchors or aliases.
- No custom tags.
- Quote strings that look like booleans or dates, such as `"on"`, `"off"`, and `"2026-06-16"`.
- Every config object must have a stable `id`.
- References must use IDs, not display names.
- Every file must pass schema validation before generation.

## Recommended ID Style

Use lower snake case with a category prefix:

```text
unit_knight
unit_slime
skill_fireball
buff_burn
stage_forest_001
wave_forest_001_a
item_iron_sword
```

## Directory Ownership

Shared data goes under `data/common/` only when it is intentionally reusable across multiple genres.

Genre data goes under `data/genres/<genre>/` when it contains genre-specific assumptions, such as:

- Turn queue rules
- Real-time cooldown rules
- Grid or tile assumptions
- Tower placement rules
- Idle economy curves

## Example Source YAML

```yaml
id: skill_fireball
name: Fireball
target: enemy
cooldown: 3
effects:
  - type: damage
    element: fire
    power: 120
  - type: status
    status_id: buff_burn
    chance: 0.25
    duration: 3
```

## Generated Runtime JSON

Generated JSON should be stable, normalized, and easy to diff.

```json
{
  "id": "skill_fireball",
  "name": "Fireball",
  "target": "enemy",
  "cooldown": 3,
  "effects": [
    {
      "type": "damage",
      "element": "fire",
      "power": 120
    },
    {
      "type": "status",
      "status_id": "buff_burn",
      "chance": 0.25,
      "duration": 3
    }
  ]
}
```

## Validation Priorities

Validation should catch:

- Missing required fields
- Duplicate IDs
- Invalid enum values
- Broken references
- Negative or impossible numeric values
- Unsupported effect types
- Runtime fields accidentally edited by hand

## Versioning

Generated data should eventually include:

- `schema_version`
- `content_version`
- `generated_at`
- `source_hash`

The first version can omit this until the generator exists.
