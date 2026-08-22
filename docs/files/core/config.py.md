# File: `core/config.py`

## Purpose
Defines and instantiates the single source of truth for environment-driven configuration used across the entire application.

## Responsibilities
- Declare every environment variable the application needs, with types and (where sensible) defaults.
- Load values from a `.env` file automatically.
- Provide a convenience property for parsing a comma-separated host list.
- Instantiate one shared `settings` object other modules import.

## Imports
| Import | Used for |
|---|---|
| `pydantic_settings.BaseSettings, SettingsConfigDict` | Base class and config for environment-variable-backed settings models |

## Exports
- **`Settings`** â€” the class definition (rarely imported directly elsewhere; used internally).
- **`settings`** â€” the singleton instance; this is what every other module actually imports (`from core.config import settings`).

## Execution Flow
1. On import, Python defines the `Settings` class.
2. `settings = Settings()` executes immediately at module load â€” this reads `.env` (and the real process environment, which takes precedence per `pydantic-settings` conventions) and validates every field.
3. If any required field (`MONGODB_URI`, `MILVUS_URI`, `EMBED_MODEL`, `LLM_MODEL`, `Vela_API_KEY`) is missing, this line raises a `pydantic.ValidationError` immediately â€” before any other code in the importing module runs.

## Functions (plain English)

### `Settings.ollama_hosts_list` (property)
In simple English: "If `OLLAMA_HOSTS` was set as a comma-separated string like `'host1,host2'`, split it into a clean list `['host1', 'host2']`, trimming any extra spaces. If it wasn't set at all, just give back an empty list." This is a computed property, not a stored field â€” it recalculates every time it's accessed (cheap, since it's just a string split).

## Classes

### `Settings(BaseSettings)`
A Pydantic settings model â€” essentially a typed, validated dictionary of environment variables. Fields: `MONGODB_URI` (required `str`), `MONGODB_DB_NAME` (`str`, defaults to `"Vela"`), `MILVUS_URI` (required `str`), `OLLAMA_URI` (`str | None`, optional), `OLLAMA_HOSTS` (`str | None`, optional), `EMBED_MODEL` (required `str`), `LLM_MODEL` (required `str`), `Vela_API_KEY` (required `str`). `model_config` points to a `.env` file for loading. No custom validators are defined â€” field types alone provide validation.

## Interfaces
`Settings` itself functions as a data contract/interface for "what configuration does this app need" â€” any code that needs a config value should read it from here rather than calling `os.environ` directly (a convention followed everywhere except `milvus/insert_vectors.py`'s `os.getenv` call and `scripts/mock_seeder.py`'s hardcoded values â€” see those files' docs).

## Hooks
Not applicable â€” no FastAPI-specific hooks in this file.

## Utilities
None beyond the `ollama_hosts_list` property described above.

## Dependencies
`pydantic-settings` only. No internal dependencies â€” this is a leaf module with respect to the rest of the codebase (everything depends on it; it depends on nothing internal).

## Side Effects
- **Reads the filesystem** (`.env`) and the process environment at import time.
- **Raises an exception at import time** if required fields are missing â€” this is a deliberate fail-fast side effect, but it means simply importing this module (even without using `settings` for anything) can crash the importing process.

## Performance Considerations
Negligible â€” settings are parsed once at import time and cached in the `settings` singleton for the lifetime of the process; there's no per-request cost.

## Possible Interview Questions
- "Why does `Settings()` get instantiated at module import time rather than lazily, e.g. inside a `get_settings()` function?" (Simplicity and fail-fast behavior â€” misconfiguration is caught immediately at process startup rather than at some arbitrary later point when a setting is first accessed; the trade-off is that even importing this module for an unrelated reason can crash if `.env` is misconfigured.)
- "What's the precedence between a value in `.env` and the same-named variable already set in the process environment?" (`pydantic-settings` gives real environment variables precedence over `.env` file values by default â€” worth confirming this matches the team's expectations in containerized deployments where env vars are typically injected directly.)
- "If you needed to swap `MONGODB_URI` at runtime for a test, how would you do it given `settings` is a module-level singleton instantiated once?" (You'd need to either monkeypatch `settings` directly, use `pydantic-settings`' env-var override mechanism before import, or refactor to a lazy `get_settings()` pattern with dependency injection â€” this file's current design makes runtime reconfiguration awkward by design.)

