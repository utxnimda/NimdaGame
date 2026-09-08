# Development conventions

## Responsibilities

- C++ core owns portable gameplay rules. Keep Godot and transport types out of core.
- Godot screens own layout, selection and interaction state.
- Editor models own record defaults, normalization and fast user feedback.
- Editor adapters own file and subprocess access. They return a consistent
  dictionary with `ok`, `data` and `error`; screens do not launch Python directly.
- Python database services own authoritative schema/semantic validation and
  persistence. They do not print or depend on CLI arguments.
- Command-line modules translate arguments and errors into service calls and exit
  codes. Preserve both direct-script and installed entrypoints.
- Shared repository paths live in `tools/mygame_tools/paths.py`.

## Extending a database

1. Add the source YAML and JSON Schema.
2. Register a `DatabaseSpec` in `tools/mygame_tools/databases.py`.
3. Supply a semantic validator for domain rules that JSON Schema cannot express.
   Validators receive schema-valid data and return error messages.
4. Reuse `database.py` for reading, generation and saving. Its contract is a root
   object with `schema_version` and a collection of record objects. String record
   IDs are checked for duplicates.
5. Reuse `database_client.gd` for editor IO and `database_form.gd` for fields.
   The editor adapter currently expects the collection key to match the database
   name and supports schema version 1. Add an explicit migration before changing
   that version.
6. Test domain rules and failure behavior with temporary paths, not authored files.

The actor editor is split into these components:

| File | Responsibility |
| --- | --- |
| `rpg_editor_main.gd` | Screen layout and user actions |
| `actor_database.gd` | Actor defaults, normalization, ID allocation and feedback |
| `database_form.gd` | Reusable fields, signal suppression and record display |
| `database_client.gd` | Python execution and generated JSON loading |
| `database.py` | Reusable validation, staging and persistence |
| `databases.py` | Database registration and actor domain rules |
| `rpg_editor_data.py` | CLI and compatibility exports |

## Save semantics

The editor carries the source hash returned by the last successful load/save.
Python rejects a stale hash before changing the source. Both outputs and a source
backup use unique staging files beside their destinations. If runtime replacement
fails after source replacement, the service restores the original source. Runtime
generation also replaces its output atomically.

These are protections against ordinary IO errors and stale edits, not a database
transaction: there is no cross-process writer lock or crash-atomic two-file commit.
YAML remains authoritative; regenerate JSON after an interrupted operation.
The editor adapter currently executes Python synchronously. Future asynchronous
execution belongs in that adapter, without changing form or model code.

## Style

- `.editorconfig` defines UTF-8, LF, final newlines and indentation: four spaces
  for Python/C++, tabs for GDScript, two spaces for JSON/YAML.
- Ruff is pinned in the development dependencies to keep local and CI formatting
  consistent. Use snake_case for Python/GDScript functions, PascalCase for Python
  classes and preloaded Godot scripts, and UPPER_SNAKE_CASE for value constants.
- Python APIs use type hints; GDScript public methods declare argument and return
  types. Keep language-specific conventions instead of forcing identical syntax.
- Keep the existing C++ namespace and naming style. Prefer small value types and
  engine-independent functions.
- Domain rules must not migrate into UI components. UI validation gives early
  feedback; Python remains authoritative for authored data.
- Add tests for behavior and failure boundaries rather than field-by-field copies
  of implementation details.

## Checks

From the repository root:

```powershell
python -m pip install -e "tools[dev]"
python -m ruff check tools
python -m ruff format --check tools
python -m pytest tools/tests -q
python tools/mygame_tools/generate_godot_data.py
python tools/mygame_tools/release_pipeline.py check
```

To apply Python formatting, run `python -m ruff format tools`.

When Godot is on PATH, pytest also runs a headless editor behavior test with a fake
data client. It does not save authored actor data. Without Godot that test is
explicitly skipped. The standalone command is:

```powershell
godot --headless --path clients/godot --script ../../tools/godot/test_rpg_editor.gd
```

CI runs Python checks, data generation and C++ compilation on Linux and Windows.
Export commands prepare validated runtime data before invoking Godot.
