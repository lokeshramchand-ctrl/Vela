# Folder: `scripts/`

## Purpose
Manual, operator-invoked utilities for bootstrapping data and smoke-testing the running API. Nothing here is imported by the application itself â€” everything is a standalone entry point run with `python scripts/<file>.py` or `bash scripts/test_pipeline.sh`.

## Responsibilities
- Seed canonical merchant/alias records so `services/merchant_resolver.py` has data to match against (`seed.py`).
- Inject and clean up realistic, clearly-flagged (`is_mock: True`) synthetic transactions for exercising the analytics engine (`mock_seeder.py`).
- Drive a full curl-based end-to-end smoke test against a running server (`test_pipeline.sh`).

## Why this folder exists
The application has zero automatic data-bootstrapping (no migrations, no `on_startup` seed logic) â€” every collection starts empty. This folder exists to fill that gap manually, since a fresh MongoDB instance otherwise leaves nearly every endpoint returning trivial "Unknown"/empty results. Keeping these as separate, explicitly-invoked scripts (rather than folding seeding into `app.py`'s lifespan) is the correct choice â€” you never want production startup to silently reseed or inject mock data.

## How it interacts with other folders
`seed.py` imports `database.mongo.db` and writes directly to the `merchants` collection â€” but calls `db.connect()` with **no arguments**, relying on `MongoDB.connect`'s fallback to `settings.MONGODB_URI`/`settings.MONGODB_DB_NAME` (this works because `connect` explicitly defaults `uri`/`db_name` to `None` and falls back to `core.config.settings` internally). `mock_seeder.py` deliberately does **not** import `database/mongo.py` at all â€” it constructs its own raw `AsyncIOMotorClient` against a hardcoded `MONGO_URI = "mongodb://localhost:27017"`, bypassing `core.config.settings` entirely. `test_pipeline.sh` doesn't import anything (it's bash) but drives HTTP calls against every router in `routers/` and shells out to `mock_seeder.py`.

```mermaid
flowchart TD
    seedPy[scripts/seed.py] --> mongo[database/mongo.py]
    mockSeeder[scripts/mock_seeder.py] -.bypasses, own hardcoded client.-> motor[motor.motor_asyncio directly]
    testPipeline[scripts/test_pipeline.sh] -->|curl| routersV1[routers/v1.py]
    testPipeline -->|curl| routersMemory[routers/memory.py]
    testPipeline -->|curl| routersAnalytics[routers/analytics.py]
    testPipeline -->|shells out to| mockSeeder
```

## Major files
| File | Purpose | Idempotent? |
|---|---|---|
| `seed.py` | Seeds `merchants` (Swiggy, Zomato, Netflix + aliases) | Yes â€” `delete_many({})` then `insert_many(...)`, safe to rerun |
| `mock_seeder.py` | Injects/cleans up 100 mock `transactions` for `user_id: "user_123"` | Yes â€” `cleanup` mode deletes exactly what `seed` mode marks `is_mock: True` |
| `test_pipeline.sh` | Curl-driven E2E smoke test | Mostly â€” creates a fresh `Zomato`-named memory profile each run rather than a unique name, so state accumulates across runs unless memory data is reset |

## Important classes
None â€” every file in this folder is procedural (top-level `async def seed()`/`cleanup()` functions or, for the shell script, sequential `curl` commands).

## Important functions
- **`seed.py::seed()`** â€” `db.connect()` â†’ clear and repopulate `merchants` â†’ `db.disconnect()`.
- **`mock_seeder.py::seed()`** â€” generates 100 transactions across a random pool of 10 merchant/category pairs, random amounts (â‚¹50â€“2500), random dates within the last 60 days, all tagged `is_mock: True`.
- **`mock_seeder.py::cleanup()`** â€” `delete_many({"user_id": "user_123", "is_mock": True})`.
- **`test_pipeline.sh`** â€” sequential curl calls: resolve â†’ memory update Ã—3 (to trigger `TEMPORARY` promotion) â†’ confidence evaluate â†’ invoke `mock_seeder.py` â†’ analytics queries â†’ invoke `mock_seeder.py cleanup`.

## Execution order
These scripts have no relationship to `app.py`'s startup at all â€” they must be run manually, and in a specific order relative to each other for a fully realistic demo: `seed.py` (merchants) should run before exercising `/v1/resolve` meaningfully; `mock_seeder.py` should run before exercising `/v1/analytics/*`; and `behaviour/behavior_engine.py` (not itself a script â€” no CLI wrapper exists for it) would need to run after `mock_seeder.py` and before `/v1/analytics/subscriptions`/`anomaly/check` for those specific endpoints to return non-trivial results. `test_pipeline.sh` encodes part of this ordering (seed mock data â†’ query analytics â†’ clean up) but not the `behaviour/` step, since that step has no script entry point at all.

## Dependency graph
```mermaid
flowchart LR
    seed.py --> asyncio
    seed.py --> database.mongo
    mock_seeder.py --> asyncio
    mock_seeder.py --> motor.motor_asyncio
    test_pipeline.sh --> bash_builtins["bash, curl, grep"]
```

## Call graph
```mermaid
sequenceDiagram
    participant Op as Operator
    participant Seed as scripts/seed.py
    participant Mock as scripts/mock_seeder.py
    participant Pipeline as scripts/test_pipeline.sh
    participant API as running Vela server

    Op->>Seed: python scripts/seed.py
    Seed->>Seed: db.connect() -> merchants.delete_many + insert_many -> db.disconnect()

    Op->>Pipeline: bash scripts/test_pipeline.sh
    Pipeline->>API: curl /v1/resolve, /memory/update x3, /v1/confidence/evaluate
    Pipeline->>Mock: python scripts/mock_seeder.py
    Mock->>Mock: insert_many(100 mock transactions)
    Pipeline->>API: curl /v1/analytics/patterns/merchants, /v1/analytics/patterns/categories
    Pipeline->>Mock: python scripts/mock_seeder.py cleanup
    Mock->>Mock: delete_many({is_mock: True})
```

## Potential interview questions
- "Why does `mock_seeder.py` construct its own MongoDB client instead of using `database/mongo.py`?" (No stated reason in the code â€” likely written independently/earlier, or deliberately avoiding the app's settings-driven connection in favor of a hardcoded local default for quick manual testing. Worth flagging as inconsistent with how the rest of the codebase accesses Mongo.)
- "`test_pipeline.sh` always uses the literal merchant name `'Zomato'` for its memory-engine test. What happens if you run it twice in a row?" (The `Zomato` profile's `frequency` keeps incrementing across runs rather than starting fresh at `EPHEMERAL` each time â€” after enough runs, it would already be `PERMANENT` before the script's own encounters even begin, changing the state-transition assertions' meaning silently.)
- "Why tag mock transactions with `is_mock: True` instead of just deleting all transactions for `user_123` during cleanup?" (Protects against accidentally deleting real, non-mock data that might legitimately exist for that same test user ID â€” a defensive habit worth having even in a test/seed script.)
- "`test_pipeline.sh` hits `http://localhost:8080` by default. Does that match how the app is actually started elsewhere in this repo?" (No â€” `Dockerfile`'s `CMD` and `docker-compose_local.yaml`'s internal port are `8000` (external `9850`), and `app.py`'s dev entrypoint also uses `8000`. `README.md`'s manual `uvicorn` instructions use `8080`. This script's `BASE_URL` needs manual adjustment depending on how you started the server â€” a small but real friction point.)

## Common mistakes
- Running `mock_seeder.py` against a different MongoDB instance than the one the app is actually configured to use â€” it hardcodes `mongodb://localhost:27017`, ignoring `.env`'s `MONGODB_URI` entirely.
- Forgetting to run `mock_seeder.py cleanup` after manual testing, leaving synthetic `is_mock: True` transactions mixed into `user_123`'s data (though `is_mock` at least makes them identifiable for later manual cleanup).
- Assuming `test_pipeline.sh`'s `BASE_URL=http://localhost:8080` matches your local setup â€” check which port you actually started the server on first.
- Assuming these scripts are exercised in CI â€” there is no CI configuration in this repository; these are 100% manual-invocation tools.

## Why this design is good
- Keeping seed/mock data generation as standalone scripts, entirely separate from application startup, is the correct safety boundary â€” there's no risk of a misconfigured environment variable accidentally triggering destructive `delete_many`/`insert_many` calls against production data during a normal deploy.
- Tagging synthetic data with an explicit `is_mock` flag is a simple, effective convention that makes cleanup safe and auditable, and is a good practice worth replicating in any future seed scripts.
- `test_pipeline.sh` reading `Vela_API_KEY` from a local `.env` (with a documented fallback) makes it portable across environments without hardcoding a secret directly into the script.

## If this folder disappeared
No impact on the running application itself (nothing in `app.py` or any router imports from `scripts/`). The practical impact would be entirely operational: there would be no way to seed canonical merchant data for `/v1/resolve` to find beyond `"Unknown"`, no easy way to inject realistic mock transaction volume for testing the analytics engine, and no scripted end-to-end smoke test to run after making changes â€” every one of those steps would need to be done by hand via raw `curl`/Mongo shell commands.

