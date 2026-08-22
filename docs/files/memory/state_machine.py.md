# File: `memory/state_machine.py`

## Purpose
A pure, side-effect-free decision function encoding the Phase 4 promotion rules: how many times must an entity be seen before it earns more trust.

## Responsibilities
- Hold the two frequency thresholds (`TEMPORARY`, `PERMANENT`).
- Given a profile's current state and frequency, decide what state it should be in now.

## Imports
| Import | Used for |
|---|---|
| `models.schemas.MemoryState, MerchantProfile` | The state enum and the profile type being evaluated |
| `logging` | Logging promotion events |

## Exports
- **`StateMachine`** — the class.
- **`state_machine`** — the singleton instance, imported by `memory/memory_manager.py`.

## Execution Flow
On import, `state_machine = StateMachine()` runs, setting the two threshold constants. `evaluate_promotion(...)` is called synchronously, per encounter, from `memory/memory_manager.py`.

## Functions (plain English)

### `StateMachine.__init__(self)`
In simple English: "Remember the two magic numbers that decide promotions: you need to be seen 3 times to become TEMPORARY, and 10 times to become PERMANENT."

### `StateMachine.evaluate_promotion(self, profile: MerchantProfile) -> MemoryState`
In simple English: "Look at how many times this merchant has been seen, and what trust level it's currently at, and decide what trust level it *should* be at now. If it's already PERMANENT or ARCHIVED, don't change anything — those are considered final states as far as this function is concerned. Otherwise: if it's been seen 10 or more times, promote it straight to PERMANENT. If it's been seen at least 3 times (but fewer than 10), it should be TEMPORARY — and if it was just freshly EPHEMERAL before this, log that this is a new promotion. If it's been seen fewer than 3 times, it stays at EPHEMERAL, the starting level." This function reads a profile's data but never modifies it — the caller (`memory_manager`) is responsible for actually applying whatever state this function returns.

## Classes

### `StateMachine`
Instance attributes: `self.TEMPORARY_THRESHOLD = 3`, `self.PERMANENT_THRESHOLD = 10` (both set once in `__init__`, effectively constants despite being instance attributes rather than class-level constants).

## Interfaces
`evaluate_promotion(profile: MerchantProfile) -> MemoryState` is a clean, pure function contract: same input always produces the same output, with no hidden state or side effects — an ideal candidate for unit testing (though none currently exist).

## Hooks
Not applicable.

## Utilities
None — the class has exactly one meaningful method beyond its constructor.

## Dependencies
`models.schemas` (internal); `logging` (standard library).

## Side Effects
The **only** side effect anywhere in this file is logging (`logger.info(...)`) when a profile is newly promoted to `PERMANENT` or freshly promoted from `EPHEMERAL` to `TEMPORARY` — there is no I/O, no database access, and no mutation of the `profile` argument passed in.

## Performance Considerations
Effectively free — a couple of integer comparisons and enum checks per call. This function could run millions of times per second with no measurable performance impact; the actual cost of the surrounding `process_encounter` flow is entirely dominated by the database calls in `memory/memory_manager.py`, not this.

## Possible Interview Questions
- "Why are `TEMPORARY_THRESHOLD` and `PERMANENT_THRESHOLD` instance attributes set in `__init__` rather than class-level constants?" (Functionally equivalent here since there's only ever one instance (`state_machine`), but class-level constants (`TEMPORARY_THRESHOLD = 3` directly under `class StateMachine:`) would be a slightly more idiomatic way to express 'these never change per-instance' — worth discussing as a minor style point.)
- "Can a profile ever skip directly from `EPHEMERAL` to `PERMANENT` without passing through `TEMPORARY`?" (Yes — if `frequency` jumps to 10 or more in a single update (e.g., a backfill script that sets frequency directly, or if the threshold check order allowed it), `evaluate_promotion` would return `PERMANENT` immediately since that check happens first and doesn't require having previously been `TEMPORARY`.)
- "Why does this function treat `ARCHIVED` as sticky, when `memory_manager.py` later explicitly overrides that for the 'wake up' case?" (Separation of concerns — this function's job is purely 'what does frequency alone justify,' and archival/reactivation is treated as a distinct concept the calling code handles separately, keeping this function's logic simpler and focused only on the frequency-based promotion ladder.)
- "How would you unit test this function exhaustively?" (Since it's pure, you could enumerate every combination of `(current_state, frequency)` — four states × a handful of representative frequency values — construct a `MerchantProfile` for each, and assert the expected output state, with zero mocking required.)
