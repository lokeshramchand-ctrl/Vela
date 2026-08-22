# File: `scripts/test_pipeline.sh`

## Purpose
A manual, human-readable, curl-driven end-to-end smoke test that walks through several major features of a *running* Vela server, printing narrated output as it goes.

## Responsibilities
- Resolve an API key (from `.env` if present, otherwise a hardcoded fallback).
- Exercise merchant resolution, memory-state promotion, and the confidence wall.
- Seed and then query mock analytics data.
- Clean up after itself.

## Imports
Not applicable in the Python sense â€” this is a bash script. It relies on external programs: `curl` (HTTP requests), `grep`/`cut`/`tr` (parsing `.env`), `python` (invoking `scripts/mock_seeder.py`).

## Exports
Not applicable â€” a script meant to be run directly (`bash scripts/test_pipeline.sh`), not sourced or imported.

## Execution Flow
Runs top-to-bottom, sequentially, with `sleep 1` pauses between logical sections (presumably to make the narrated output easier for a human to read live, not for any technical synchronization need â€” the underlying HTTP calls are already synchronous and complete before the script moves on):
1. Resolve `API_KEY` (from `.env` if found, else hardcoded fallback).
2. Print a banner.
3. Test merchant resolution (`/v1/resolve`) with one noisy example string.
4. Test memory promotion (`/memory/update`) â€” calls it 3 times in a loop for the same fixed merchant name (`Zomato`), intended to demonstrate the `EPHEMERAL â†’ TEMPORARY` transition.
5. Test the confidence wall (`/v1/confidence/evaluate`) with a deliberately low-confidence example.
6. Run `scripts/mock_seeder.py` (seed mode) to inject test analytics data.
7. Query two analytics endpoints (`/v1/analytics/patterns/merchants`, `/v1/analytics/patterns/categories`).
8. Run `scripts/mock_seeder.py cleanup` to remove the injected data.
9. Print a completion banner.

## Functions (plain English)
Bash scripts don't have "functions" in this file (no `function` blocks are defined) â€” every step is a sequential, top-level command. Described section by section:

### API key resolution (top of script)
In simple English: "Assume the fallback test API key to start with. If there's a `.env` file sitting in the current directory, try to find a line in it that sets `Vela_API_KEY`, and if we find one, use that value instead â€” and let the user know we picked it up."

### Phase 3 block â€” merchant resolution
In simple English: "Send one example of messy bank text (`UPI/CR/3152671239/BUNDL TECHNOLOGIES/HDFC`) to the resolve endpoint and print whatever comes back, so a human can visually confirm it correctly identified 'Swiggy' (assuming the `merchants` collection has already been seeded via `scripts/seed.py`)."

### Phase 4 block â€” memory engine
In simple English: "Report the same merchant ('Zomato') as encountered three separate times in a row, printing the response each time, so a human watching can see it progress from a brand-new entity toward a more trusted one."

### Phase 5 block â€” confidence wall
In simple English: "Submit a prediction with only 40% confidence and print the response, to visually confirm the system rejects it and routes it to 'Unknown' instead of trusting a shaky guess."

### Mock data preparation block
In simple English: "Run the Python mock-seeding script to inject 100 fake transactions, so the next section has something real to analyze."

### Phase 13 block â€” analytics
In simple English: "Ask for the top 3 most-visited merchants, print the result. Then ask for a 30-day category spending breakdown, print that too."

### Cleanup block
In simple English: "Run the Python mock-seeding script again, this time in cleanup mode, to remove the fake data we just injected â€” leaving the database as close as possible to how we found it."

## Classes
Not applicable â€” bash has no classes.

## Interfaces
Not applicable.

## Hooks
Not applicable â€” no framework-level hooks; this is a linear procedural script.

## Utilities
Not applicable â€” no reusable functions are factored out; every section is a one-off inline block.

## Dependencies
External programs: `bash`, `curl`, `grep`, `cut`, `tr`, `python` (to invoke `scripts/mock_seeder.py`). Implicitly depends on a running Vela server reachable at `BASE_URL` (hardcoded to `http://localhost:8080`).

## Side Effects
- Makes real HTTP requests against a live server â€” including a state-mutating `/memory/update` call repeated 3 times for the literal merchant name `"Zomato"`, which permanently affects that merchant's `frequency`/`memory_state` in the real database every time this script is run (there is no cleanup step for this specific side effect, unlike the mock transaction data, which *is* cleaned up).
- Invokes `scripts/mock_seeder.py`, which itself inserts and later deletes 100 real MongoDB documents (see that file's own side-effects section).
- Prints extensive narrated output to the terminal.

## Performance Considerations
Not a performance-sensitive script â€” it's a manual diagnostic/demo tool, not something run in a hot path or CI. The `sleep 1` calls between sections add a few seconds of purely cosmetic delay, with no functional purpose beyond pacing the output for a human reader.

## Possible Interview Questions
- "This script hardcodes `BASE_URL=http://localhost:8080`, but the app's `Dockerfile`/`docker-compose_local.yaml` expose it on port `8000`/`9850` respectively, and the dev entrypoint in `app.py` also uses `8000`. What's the practical impact?" (Anyone running this script against a server started via Docker or the default dev entrypoint would need to manually edit `BASE_URL` first, or every single `curl` call would fail to connect â€” a real, easy-to-hit friction point when onboarding.)
- "Why does the memory-engine test always use the literal name `'Zomato'` instead of generating a unique name per run, the way `test_api.py`'s equivalent test does?" (Because this script always mutates the *same* real database record on every run â€” running it repeatedly keeps incrementing that one entity's frequency indefinitely, meaning after enough runs, 'Zomato' would already be `PERMANENT` before the script's own three encounters even begin, changing what the demonstrated state transition actually shows each time.)
- "Why parse `.env` manually with `grep`/`cut`/`tr` instead of just sourcing the file directly (e.g., `set -a; source .env; set +a`)?" (Sourcing the whole `.env` file would also export every other variable in it into the shell environment, which may be undesired or could clash with existing environment variables; the manual grep/cut approach extracts just the one specific value needed, more surgically.)
- "What would you add to this script to make it safe to run repeatedly without side effects accumulating in the real memory-engine data?" (Either generate a unique test-merchant name per run (mirroring `test_api.py`'s `uuid`-based approach), or add an explicit cleanup step afterward that removes or resets the test merchant's profile â€” currently, only the mock transaction data gets cleaned up, not the memory-engine state changes.)

