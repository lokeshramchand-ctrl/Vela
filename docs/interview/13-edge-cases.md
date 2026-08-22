# Edge Cases — 15 Questions

---

### EC1. What happens when `GET /v1/analytics/patterns/categories?days=-5` is called?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** No error — `days: int = Query(30, ...)` has no lower-bound constraint, so `-5` passes validation. `routers/analytics.py` computes `start_date = end_date - timedelta(days=-5)`, which is `end_date + timedelta(days=5)` — a start date *after* the end date. MongoDB's `$match` with `{"timestamp": {"$gte": start_date, "$lte": end_date}}` then matches zero documents (an impossible range), so the endpoint returns an empty array, not an error. `test_api.py::test_analytics_categories_negative_days` explicitly codifies this as acceptable behavior (`assert response.status_code in [200, 422]`).
- **Follow-ups:** "Should this be rejected with a 422 instead? Argue both sides."
- **Common Mistakes:** Assuming this would crash or return an error, without tracing that a reversed date range simply produces zero matches rather than throwing.
- **What This Tests:** Careful tracing of arithmetic with negative inputs through to its actual (non-crashing) consequence.
- **Red Flags:** Assumes an exception is raised without verifying.
- **Excellent Answer:** Argues both sides: rejecting with `422` (via `Query(30, ge=1)`) would be more correct API design, catching an obviously nonsensical input at the boundary — but the current behavior is at least *safe* (no crash, no wrong data, just an empty and technically-accurate result for an impossible query), which is arguably acceptable if unglamorous.
- **Poor Answer:** States a preference without engaging with the actual current (non-crashing) behavior first.

---

### EC2. What happens if `behaviour/behavior_engine.py::profile_merchant_behavior` is called for a merchant with exactly one transaction?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It doesn't raise `ValueError` (that only happens for zero transactions), but several of the underlying feature extractors degrade to trivial/degenerate values: `features/frequency_features.py` requires at least 2 timestamps for a meaningful frequency and returns all zeros for `n < 2`; `features/periodicity.py` requires at least 3 timestamps and returns `periodicity_score: 0.0` for fewer. The resulting `BehaviorPattern` would have real amount statistics (mean = the single amount, variance = 0) but zero-valued frequency and periodicity fields — a technically-valid but not very meaningful profile.
- **Follow-ups:** "Should there be a minimum-transaction-count threshold before calling this function at all, given it 'succeeds' with fairly meaningless output at n=1?"
- **Common Mistakes:** Assuming the `ValueError` guard covers "insufficient data" generally, when it actually only guards the n=0 case specifically — n=1 and n=2 pass through with silently degenerate (but not erroring) results.
- **What This Tests:** Tracing multiple different minimum-sample-size thresholds across different extractor functions and recognizing they don't align with a single "is this profile meaningful" boundary.
- **Red Flags:** Assumes one guard clause protects against all forms of insufficient data.
- **Excellent Answer:** Proposes that `behaviour/behavior_engine.py` itself should apply a higher minimum threshold (e.g., require at least 3-5 transactions) before even attempting to build a profile, rather than relying on each downstream extractor's own, inconsistent minimum thresholds to silently produce degenerate-but-valid output.
- **Poor Answer:** Only checks the `ValueError` guard without tracing the downstream extractors' own separate thresholds.

---

### EC3. What does `analytics/anomaly_detection.py::flag_transaction` return for a merchant whose `behavior_patterns.std_dev` happens to be a very small positive number (e.g., `0.01`) rather than exactly zero?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** The `std_dev == 0` guard doesn't trigger (it's not exactly zero), so the z-score calculation proceeds: `z = |amount - avg_amount| / 0.01` — for almost any amount even slightly different from `avg_amount`, this produces an enormous z-score, likely exceeding the `3.0` anomaly threshold and capping `confidence` at its maximum `0.99`. This is a near-miss of the "insufficient data" guard that produces the same practical problem (a merchant with almost-zero recorded variance triggers a maximally-confident anomaly flag for even a trivially small amount difference) without being caught by the exact-zero check.
- **Follow-ups:** "How would you fix the guard to catch this near-zero case too?"
- **Common Mistakes:** Assuming the `std_dev == 0` guard adequately protects against all "insufficient variance data" scenarios, missing that it's an exact-equality check with no tolerance.
- **What This Tests:** Recognizing that an exact-equality floating-point guard often has a much broader "effectively the same problem" zone right next to it that isn't actually caught.
- **Red Flags:** Assumes the existing guard handles this case because it's "basically zero."
- **Excellent Answer:** Proposes replacing `std_dev == 0` with a minimum-threshold check (e.g., `std_dev < some_epsilon`, or better, requiring a minimum number of underlying transactions before trusting the computed `std_dev` at all) to close this near-miss gap.
- **Poor Answer:** Doesn't recognize this as a distinct edge case from the exact-zero one already documented.

---

### EC4. Two `POST /memory/update` requests for a brand-new merchant arrive within milliseconds of each other. Walk through every possible outcome, not just the most likely one.
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** Several outcomes are possible depending on exact timing: (a) both requests' `get_profile` calls return `None` before either write completes — both proceed to `create_profile`, resulting in two separate MongoDB documents for the same `canonical_name` (no unique index prevents this); (b) one request's write completes before the other's read — the second sees the first's document via `get_profile` and correctly proceeds down the "existing profile" path instead, resulting in one document with `frequency=2`, functionally correct by luck of timing; (c) various interleavings in between are theoretically possible depending on exact database round-trip timing. There is no code that guarantees which outcome occurs — it's genuinely racy.
- **Follow-ups:** "Which outcome would `test_api.py::test_memory_engine_lifecycle` actually observe, given it uses a UUID-suffixed unique merchant name per test run?"
- **Common Mistakes:** Only describing the "bad" outcome (duplicate documents) without acknowledging the "lucky" outcome (correct behavior by timing) is equally possible and arguably more likely in most real deployments given typical database round-trip speed relative to typical request-arrival spacing.
- **What This Tests:** Genuinely thorough race-condition analysis — enumerating the full outcome space rather than jumping to the single worst-case scenario as if it were deterministic.
- **Red Flags:** Describes only one outcome as if it were guaranteed, rather than acknowledging genuine non-determinism.
- **Excellent Answer:** Correctly notes that `test_api.py`'s test wouldn't actually exercise true concurrency at all — it sends its three encounter requests *sequentially* (via `client.post(...)` calls one after another, not concurrently), so this specific race condition, despite being real and present in the code, has likely never actually been triggered by the existing test suite.
- **Poor Answer:** Assumes the test suite would have caught this race if it were real, without checking whether the test is actually structured to trigger concurrent execution.

---

### EC5. What happens when `POST /v1/explain` is called with `transaction_text: ""`(an empty string)?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Pydantic validation passes (no `min_length` constraint on `transaction_text`), so it reaches `rag/retriever.py::fetch_grounded_context`, which passes the empty string to `embedding_generator.generate("")`. Whether Ollama's embedding endpoint produces a meaningful (if arbitrary) vector for empty input, or errors, depends entirely on the specific embedding model's behavior — something this codebase doesn't handle or guard against explicitly at all. If it does produce a vector, the subsequent Milvus search would proceed against that (likely low-quality/meaningless) embedding, most plausibly returning weak or no matches, ultimately resulting in the "no context available" response.
- **Follow-ups:** "Should `transaction_text` have a `min_length=1` constraint? What about a more meaningful minimum, like 3 characters?"
- **Common Mistakes:** Assuming this would definitely error out cleanly without acknowledging the actual behavior depends on the embedding model's specific handling of empty input, which this codebase doesn't control or test.
- **What This Tests:** Comfort expressing "this depends on an external system's undocumented behavior" rather than false certainty about an edge case that genuinely can't be resolved from this codebase's source alone.
- **Red Flags:** States a definitive, unverifiable claim about what Ollama specifically does with empty input.
- **Excellent Answer:** Proposes adding `Field(..., min_length=1)` as a cheap, defensive validation improvement regardless of what Ollama actually does — closing the ambiguity at the API boundary rather than depending on an external, unverified system's behavior for correctness.
- **Poor Answer:** Confidently asserts what Ollama does with no acknowledgment of uncertainty.

---

### EC6. What happens if the Ollama LLM returns syntactically valid JSON that doesn't match the expected schema — e.g., `{"foo": "bar"}` instead of `{"explanation": ..., "confidence_in_explanation": ..., "primary_data_source": ...}`?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** `rag/generator.py::generate_explanation` calls `json.loads(data["response"])`, which succeeds (the JSON is syntactically valid) and returns `{"foo": "bar"}` as-is — there's no schema validation of the parsed response's keys anywhere in this codebase. This malformed-but-valid response is returned directly to the API client inside the `result` field, with no error raised and no indication anything went wrong.
- **Follow-ups:** "How would you add validation to catch this without breaking the current 'trust the model within reason' design?"
- **Common Mistakes:** Assuming `format: "json"` guarantees the *correct* schema, not just valid JSON syntax — a distinction already tested in Backend B14/Design Decisions DD5, worth re-verifying the candidate applies consistently here.
- **What This Tests:** Consistency — does the candidate correctly apply the syntax-vs-schema distinction established elsewhere when it's relevant to a new, concrete scenario.
- **Red Flags:** Assumes `format: "json"` alone would have prevented this.
- **Excellent Answer:** Proposes validating the parsed dict against a Pydantic model (e.g., defining an `ExplanationOutput` schema and calling `ExplanationOutput(**parsed)`), catching a `ValidationError` and converting it to the same kind of soft error response already used elsewhere in this function (`{"error": "..."}`) — consistent with the existing error-handling philosophy in this specific file.
- **Poor Answer:** Proposes a fix inconsistent with the existing error-handling conventions already established in the same file.

---

### EC7. What happens if two merchants coincidentally have overlapping aliases in the `merchants` collection — e.g., both "Swiggy" and a hypothetical new merchant both list "SWIGGY EXPRESS" as an alias?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** `services/merchant_resolver.py::resolve`'s exact-match query (`find_one({"aliases": cleaned_text})`) returns whichever document MongoDB happens to return first for a non-unique match — there's no tie-breaking logic, no ambiguity detection, and no way for the caller to know a genuine ambiguity existed. The system silently picks one answer as if it were unambiguous.
- **Follow-ups:** "Is this actually a realistic scenario given `scripts/seed.py`'s current seed data, or purely theoretical? How would you prevent it going forward?"
- **Common Mistakes:** Dismissing this as unrealistic without checking whether anything in the current codebase *prevents* it from happening (nothing does — there's no uniqueness constraint on aliases across different merchant documents).
- **What This Tests:** Recognizing that "no current example exists" and "the system prevents this from ever happening" are very different claims — the former is true, the latter is false.
- **Red Flags:** Says this can't happen without checking whether any actual constraint prevents it.
- **Excellent Answer:** Proposes a uniqueness constraint or, at minimum, a data-quality check run periodically against the `merchants` collection to detect alias overlaps across different `canonical_name` values before they cause silent misresolution in production.
- **Poor Answer:** Dismisses the scenario as unrealistic without checking for an actual preventing mechanism.

---

### EC8. What happens when `POST /v1/confidence/evaluate` receives `raw_confidence: 1.5`?
- **Difficulty:** Easy | **Importance:** 5
- **Expected Answer:** Passes Pydantic validation (no upper-bound constraint on the field). `ConfidenceEngine.calibrate_probability` clamps it: `max(0.0, min(1.0, 1.5))` = `1.0`. If the category is valid, this clamped value of exactly `1.0` clears the `0.5` threshold easily, so the prediction passes through trusted, with `confidence: 1.0` reported — silently treating an obviously invalid input (>100% confidence) as if it were a legitimate, maximally-confident prediction.
- **Follow-ups:** "Should this be rejected with a 422 instead of silently clamped?"
- **Common Mistakes:** Assuming the clamp raises a warning or is otherwise visible anywhere — it isn't; the clamping is completely silent.
- **What This Tests:** Tracing a specific numeric edge case through an actual clamping function to its precise final value, not just describing "it gets clamped" vaguely.
- **Red Flags:** Doesn't compute or state the actual resulting value (`1.0`).
- **Excellent Answer:** Argues that silently clamping an out-of-range confidence value masks what's likely a bug in whatever upstream system produced `1.5` in the first place — a `Field(ge=0.0, le=1.0)` constraint on the request model would surface that bug immediately via a clear `422`, rather than this codebase quietly absorbing and hiding it.
- **Poor Answer:** States the value gets "clamped" without computing the specific resulting number or discussing whether silent clamping is the right behavior.

---

### EC9. What happens if `merchant_aliases.json` is present but contains invalid JSON (a syntax error)?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** `engines/rule_engine.py::_load_rules` only catches `FileNotFoundError` specifically — a `json.JSONDecodeError` from malformed JSON content is **not** caught, and would propagate up uncaught through `RuleEngine.__init__`, through the module-level `rule_engine = RuleEngine()` instantiation, crashing the import of `engines/rule_engine.py` entirely — and since `routers/v1.py` imports this module, the whole `/v1` router (and therefore `app.py`) would fail to import.
- **Follow-ups:** "Why might the original author have only guarded against the missing-file case and not the malformed-content case?"
- **Common Mistakes:** Assuming the same graceful "log a warning, start with empty rules" fallback applies to any file-loading problem, when it's actually scoped narrowly to one specific exception type.
- **What This Tests:** Precise reading of an exception handler's exact scope (`except FileNotFoundError:`) rather than assuming broad, general error tolerance.
- **Red Flags:** Assumes malformed JSON is handled the same gracefully as a missing file.
- **Excellent Answer:** Speculates plausibly that the missing-file case was likely considered a normal, expected condition (e.g., "the JSON file hasn't been created yet in a fresh checkout"), while malformed JSON was likely never considered as a realistic failure mode worth explicitly guarding — and proposes broadening the `except` clause to also catch `json.JSONDecodeError` with the same graceful fallback, for consistency.
- **Poor Answer:** Doesn't identify the specific, narrow scope of the existing exception handler.

---

### EC10. What happens if `clustering/cluster_engine.py::run_discovery_pipeline` is called (hypothetically, once its two known bugs are fixed) with exactly 10 vectors in Milvus — right at its stated minimum threshold?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** The guard is `if len(results) < 10:` — so exactly 10 vectors does *not* trigger the early-abort path (`10 < 10` is `False`), meaning the pipeline proceeds to run UMAP and HDBSCAN on exactly 10 data points. Whether this produces meaningful clusters is a separate statistical question (10 points is a very small sample for either algorithm), but the code itself does not treat 10 as "still insufficient" — only 9 or fewer would trigger the abort.
- **Follow-ups:** "Is 10 actually a statistically reasonable minimum for HDBSCAN with `min_cluster_size=5`?"
- **Common Mistakes:** Assuming the threshold check is inclusive/exclusive in the wrong direction without tracing the exact comparison operator (`<` vs `<=`).
- **What This Tests:** Precision about boundary conditions in a simple comparison — a classic off-by-one-style verification exercise.
- **Red Flags:** Gets the boundary direction wrong (claims 10 triggers the abort).
- **Excellent Answer:** Connects this to `hdbscan_clusterer`'s own `min_cluster_size=5` configuration: with only 10 total points and a minimum cluster size of 5, at most 2 clusters could theoretically form, and HDBSCAN's own internal logic might reasonably classify most or all of these 10 points as noise anyway — suggesting 10 is a generous *technical* minimum but a statistically weak one for producing genuinely meaningful clustering output.
- **Poor Answer:** Correctly traces the boundary condition without connecting it to whether 10 is actually a reasonable choice.

---

### EC11. What happens if a `feedback` document is submitted (hypothetically, once the router is mounted) where `original_prediction` and `corrected_category` are the exact same string?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** `is_correction = original_prediction != corrected_category` evaluates to `False` — the feedback is logged to the `feedback` collection as a confirmation, not a correction, and the retraining-queue write (and the subsequent background retraining-threshold check) is skipped entirely, exactly as intended for a "the model got it right" submission.
- **Follow-ups:** "Is there any value in also tracking confirmations for model-quality monitoring, beyond just skipping them for retraining?"
- **Common Mistakes:** Assuming this represents an error condition worth rejecting, when it's actually a normal, intended, and correctly-handled case (a human confirming rather than correcting).
- **What This Tests:** Recognizing a genuinely normal, well-handled case rather than manufacturing a problem where none exists — an important calibration skill (not everything unusual-sounding is a bug).
- **Red Flags:** Treats this as a bug or an edge case needing special handling, when it's already correctly and simply handled.
- **Excellent Answer:** Notes this "confirmation" data, though correctly stored, is never actually aggregated or analyzed anywhere in the codebase (e.g., to compute an overall "human agreement rate" metric) — a missed opportunity for model-quality monitoring using data that's already being correctly captured, distinct from whether the current handling itself is broken (it isn't).
- **Poor Answer:** Manufactures a problem with the current handling that doesn't actually exist.

---

### EC12. What happens to `POST /v1/analytics/anomaly/check` if called with `amount: -500` (a negative amount)?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** No validation rejects a negative amount — `amount: float` has no constraint. The z-score calculation (`abs(amount - avg_amount) / std_dev`) uses `abs()`, so the *magnitude* of the difference is what matters, not the sign — a `-500` far from a positive `avg_amount` would compute a large z-score and could be flagged as anomalous, with the response's `reason` text describing it as "significantly lower" (per the code's direction-detection logic: `"higher" if amount > avg_amount else "lower"`), which is at least semantically sensible even for a negative input, despite negative transaction amounts arguably representing a different real-world concept (a refund/credit) that this system doesn't explicitly model or distinguish.
- **Follow-ups:** "Should negative amounts be validated/rejected, or does this system have a legitimate use for them (e.g., refunds)?"
- **Common Mistakes:** Assuming negative amounts must be rejected or would cause an error, without tracing that `abs()` already handles the sign correctly for the z-score math itself.
- **What This Tests:** Recognizing that a seemingly "invalid" input might actually be handled reasonably by existing math (due to `abs()`), while still correctly identifying the deeper, unaddressed conceptual question (does this system model refunds/credits at all).
- **Red Flags:** Assumes this crashes or produces nonsensical output without tracing the actual `abs()`-based calculation.
- **Excellent Answer:** Raises the deeper point: nowhere else in this codebase (schemas, analytics aggregations) is there any distinct handling for refunds/credits as a concept — every `amount` field is implicitly treated as a positive debit, so a negative value reaching this specific function is more likely a sign of unaddressed domain modeling than something anomaly detection specifically needs to guard against on its own.
- **Poor Answer:** Only addresses the immediate calculation without raising the broader domain-modeling question.

---

### EC13. What happens if `db.merchant_profiles.find_one` (inside `repositories/profile_repository.py::get_profile`) returns a document missing a required field that `MerchantProfile` expects, like `canonical_name`?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `MerchantProfile(**data)` would raise a Pydantic `ValidationError`, since `canonical_name` is a required field with no default — this exception isn't caught anywhere in `get_profile` or its callers (`memory/memory_manager.py`, `routers/memory.py`), so it would propagate up as an unhandled exception, ultimately surfacing as a generic `500` to whatever endpoint triggered it. Given nothing in this codebase currently writes a `merchant_profiles` document without `canonical_name` (it's always set via `MemoryManager.process_encounter`), this is currently a latent, theoretical risk rather than an actively-triggered one — but it would matter immediately if any future code path (a migration script, manual database edit, or a bug elsewhere) ever inserted a malformed document.
- **Follow-ups:** "Would you add explicit handling for this, given it's currently unreachable via any known code path?"
- **Common Mistakes:** Assuming Pydantic validation failures are automatically caught somewhere in the FastAPI request-handling stack — they aren't, unless explicitly wrapped, since this isn't a request-body validation (which FastAPI does handle automatically) but a *database-read*-time validation.
- **What This Tests:** Recognizing that Pydantic's automatic validation-error handling only applies to FastAPI's own request/response cycle, not to ad hoc model construction from database reads deep inside business logic.
- **Red Flags:** Assumes this would be automatically caught and converted to a clean `422` the way a bad request body would be.
- **Excellent Answer:** Recommends against defensive handling purely for this hypothetical today (since no current write path can produce it), but flags it as exactly the kind of risk that argues for the MongoDB `$jsonSchema` validator proposed in Database D16 — preventing the malformed document from ever being written in the first place is a more robust fix than trying to gracefully handle every possible way a read could encounter one.
- **Poor Answer:** Proposes defensive `try/except` handling without weighing it against the more fundamental fix (preventing bad writes at the database layer).

---

### EC14. What happens if the same `raw_text` is submitted to `POST /memory/update` for the same merchant twice in a row — does the `aliases` list grow unboundedly?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** No — `memory/memory_manager.py::process_encounter` explicitly checks `if raw_text not in profile.aliases:` before appending, so an exact repeat of a previously-seen `raw_text` string does not add a duplicate entry. However, this is an exact-string check, not a normalized/fuzzy one — two raw texts that are semantically identical but differ by whitespace, casing, or punctuation (e.g., `"paid to zomato"` vs. `"Paid To Zomato"`) would each be treated as distinct and both appended, meaning `aliases` *can* still grow with near-duplicate entries over time, just not exact-duplicate ones.
- **Follow-ups:** "How would you normalize alias storage to prevent near-duplicate growth, drawing on a pattern already used elsewhere in this codebase?"
- **Common Mistakes:** Assuming the exact-match check fully prevents any form of alias-list bloat, missing the near-duplicate gap.
- **What This Tests:** Distinguishing "prevents exact duplicates" from "prevents all forms of redundancy" — a subtle but real distinction.
- **Red Flags:** States the aliases list can never contain redundant-looking entries, without qualifying the exact-match limitation.
- **Excellent Answer:** Proposes reusing `services/merchant_resolver.py::clean_text`'s normalization logic (strip noise, uppercase, collapse whitespace) before the `aliases` membership check and storage — a pattern already proven elsewhere in this exact codebase for exactly this kind of "same real-world text, different surface form" problem.
- **Poor Answer:** Proposes a new, unrelated normalization scheme without recognizing the codebase already has a directly reusable pattern for this.

---

### EC15. Design and describe (don't just name) the single most valuable new automated test you'd add to `test_api.py`, chosen specifically to catch the highest-severity currently-undetected class of bug discussed anywhere in this interview.
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** A strong answer proposes a test that imports and directly exercises `repositories/profile_repository.py` (or, more broadly, `app` itself) at module-import time and asserts it succeeds without raising — this single test would have caught the `Optional` missing-import bug, which is plausibly the single highest-severity, most invisible defect in the entire codebase (likely preventing the whole application from starting), and which no *behavioral* test (one that assumes the app already imported successfully, as `test_api.py`'s existing `client` fixture does) could ever catch, since it fails before any test body even runs.
- **Follow-ups:** "Why wouldn't the existing test suite have already caught this, given it does import `app` at the top of the file?"
- **Common Mistakes:** Proposing a narrow, single-bug-specific test (e.g., "test that `/v1/categorize` returns 200") rather than recognizing the more valuable, general-purpose test is one that validates the *entire import graph* succeeds — catching this specific bug and any future one of the same shape.
- **What This Tests:** The single hardest synthesis question in the whole interview bank — can the candidate identify, out of everything discussed across 13 categories, the one test that would deliver the most protective value, and articulate precisely why.
- **Red Flags:** Proposes a test that wouldn't actually have caught the highest-severity bug discussed (the `Optional` import issue), or picks a lower-severity bug as the target without justifying why it outranks the import-time crash.
- **Excellent Answer:** Directly answers the follow-up: `test_api.py` *does* import `app` at the top of the file (line 7, `from app import app`), which means — if the `Optional` bug is genuinely present as documented — the entire test file should currently fail to even *collect* in `pytest`, let alone run its individual tests; this is worth stating plainly as evidence that either the bug has already been silently fixed in the running environment, or the test suite has literally never been run successfully against this exact codebase state — both are important, decision-relevant possibilities to distinguish before doing anything else.
- **Poor Answer:** Proposes a reasonable but lower-value test without engaging with the specific, highest-severity bug this question is designed to surface.
