# Backend — 25 Questions

---

### B1. Walk me through exactly why `POST /v1/categorize` fails on every call, in the order the failures would occur.
- **Difficulty:** Medium | **Importance:** 10
- **Expected Answer:** First, `request.get("text", "")` is called on `request`, a `CategorizeRequest` Pydantic model — Pydantic `BaseModel` instances have no `.get()` method, so this raises `AttributeError` immediately. If that were fixed, `datetime.now(time.timezone.utc)` would raise a second `AttributeError`, since `time.timezone` is a plain integer (UTC offset in seconds), not an object with a `.utc` attribute — the correct call would use `datetime.timezone.utc`, already imported in the file as `timezone`. If that were also fixed, the Mongo document would still store `merchant_resolver` (the resolver object), `categorize_transaction` (the handler function itself), and `confidence_engine` (the engine object) instead of resolved values — unfinished placeholder code marked with `# CHANGE THIS to...` comments.
- **Follow-ups:** "How would you have found this without being told?" "Why didn't the test suite catch this?"
- **Common Mistakes:** Stopping at the first bug found and not tracing further to discover the second, independent bug on the next line.
- **What This Tests:** Ability to trace an execution path methodically rather than stopping at the first plausible explanation.
- **Red Flags:** Only identifies one of the three problems, or claims the endpoint "mostly works."
- **Excellent Answer:** Explicitly separates "bugs that prevent execution" (the two `AttributeError`s) from "bugs that would corrupt data if execution somehow continued" (the placeholder Mongo fields) — a meaningful distinction for prioritizing fixes.
- **Poor Answer:** "It probably has a typo somewhere" — vague, no specific tracing.

---

### B2. Why does `engines/rule_engine.py` pre-compile every regex pattern in `__init__` instead of compiling on each `categorize()` call?
- **Difficulty:** Easy | **Importance:** 5
- **Expected Answer:** Regex compilation is a non-trivial cost relative to matching; since the alias dictionary is static and loaded once at startup, compiling once and reusing the compiled pattern on every subsequent call amortizes that cost across the life of the process instead of paying it on every request.
- **Follow-ups:** "What would happen to this design if `merchant_aliases.json` needed to support hot-reloading?"
- **Common Mistakes:** Not recognizing this as a standard, well-justified caching pattern.
- **What This Tests:** Basic performance-reasoning fluency.
- **Red Flags:** Can't explain why compiling regex repeatedly would be wasteful.
- **Excellent Answer:** Notes that hot-reloading the alias file would require re-running `_compile_patterns()` explicitly, since the current design assumes the rule set never changes after `RuleEngine.__init__` runs once.
- **Poor Answer:** "It's faster" with no explanation of why.

---

### B3. `RuleEngine.categorize()` returns the *first* matching alias, not the *best* match. What's the practical risk?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Because `compiled_rules` iterates in JSON key insertion order, if multiple aliases could plausibly match the same text, whichever appears earlier in `merchant_aliases.json` always wins — regardless of match specificity. With the current small, mostly non-overlapping alias set this is low-risk, but it's a design smell that would get worse as the dictionary grows and aliases start to overlap (e.g., a generic word that's also a specific brand name).
- **Follow-ups:** "How would you redesign this to prefer the most specific match?"
- **Common Mistakes:** Assuming the rule engine does any kind of scoring or ranking — it doesn't; it's pure first-match-wins.
- **What This Tests:** Understanding of a subtle, low-probability-but-real correctness risk in a seemingly simple function.
- **Red Flags:** Assumes longer/more specific matches are automatically preferred without checking the code.
- **Excellent Answer:** Proposes sorting rules by alias length (longest-first) at compile time as a simple, low-cost improvement that would prefer more specific matches without a full rewrite.
- **Poor Answer:** "It just checks for a match" with no acknowledgment of the ordering risk.

---

### B4. Why does `services/merchant_resolver.py` skip words shorter than 4 characters in its substring-matching fallback?
- **Difficulty:** Easy | **Importance:** 5
- **Expected Answer:** To avoid false-positive matches against common short corporate-suffix noise like `LTD`, `PVT`, or `INC` that could coincidentally prefix-match unrelated merchants' aliases in the database.
- **Follow-ups:** "What's a real input where this heuristic could still produce a false positive?"
- **Common Mistakes:** Not connecting this specifically to the domain (Indian company suffixes) that motivates the choice.
- **What This Tests:** Reading comprehension of a small but deliberate business-logic detail.
- **Red Flags:** Guesses "performance reasons" without checking the actual purpose.
- **Excellent Answer:** Constructs a plausible false-positive example — e.g., a 4+ character common word that happens to prefix an unrelated merchant's alias — showing the heuristic is a mitigation, not a guarantee.
- **Poor Answer:** No specific reasoning, just restates that short words are skipped.

---

### B5. `merchant_resolver.py` imports both `logging` and `typing.Optional`, but neither is actually used meaningfully. Explain precisely what each import does and doesn't do.
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** `logging` is used to create `logger = logging.getLogger(__name__)`, but `logger` is never actually called anywhere in the file — so the import isn't fully dead, but produces zero log output at runtime. `typing.Optional` is imported but never referenced in any type hint anywhere in the file — a fully dead import.
- **Follow-ups:** "How would a linter catch each of these differently?"
- **Common Mistakes:** Calling both "unused imports" without distinguishing that one is used (to build an inert logger object) and one isn't referenced at all.
- **What This Tests:** Precision — many candidates will round both off to "unused" without checking the actual distinction.
- **Red Flags:** Says "both are completely unused" — factually imprecise about the `logging` case.
- **Excellent Answer:** Notes that most linters (e.g., `pyflakes`) would flag the unused `Optional` import but would *not* flag `logging`, since the module is technically used (to construct `logger`), even though the resulting object does nothing.
- **Poor Answer:** Doesn't distinguish the two cases.

---

### B6. Why does `memory/memory_manager.py::process_encounter` override the state machine's own output specifically for `ARCHIVED` profiles?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** `StateMachine.evaluate_promotion` treats `ARCHIVED` as sticky/terminal by design — it never promotes an archived profile out of that state on its own. `process_encounter` encodes a separate business rule: seeing an archived entity again is itself meaningful evidence that it's relevant again, so it forces a direct transition to `TEMPORARY`, bypassing the state machine's own (intentionally conservative) logic for that one case.
- **Follow-ups:** "Should this override live in `state_machine.py` instead, for cohesion?" "Does the profile's `frequency` reset on this transition?"
- **Common Mistakes:** Assuming this is a bug rather than a deliberate, if unusual, design choice.
- **What This Tests:** Whether the candidate can distinguish "code that looks unusual" from "code that's actually wrong."
- **Red Flags:** Calls this a bug without engaging with the business logic it's expressing.
- **Excellent Answer:** Notes that `frequency` is *not* reset on reactivation, which creates a follow-on effect: a reactivated profile can re-qualify for `PERMANENT` almost immediately, since its accumulated frequency from before archival still counts.
- **Poor Answer:** Describes the override mechanically without connecting it to the frequency-reset consequence.

---

### B7. Two requests to `POST /memory/update` arrive for the same brand-new `canonical_name` at nearly the same instant. What happens?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** Both requests independently call `get_profile`, both see "not found," both construct a fresh `MerchantProfile(frequency=1, ...)`, and both call `create_profile`, which does a plain `insert_one` — not an upsert. Since there's no unique index on `canonical_name`, this can result in two separate documents for the same logical entity, or at minimum a lost update depending on exact timing. There is no locking, no optimistic concurrency control, and no upsert-based deduplication anywhere in this path.
- **Follow-ups:** "How would you fix this with the smallest possible change?" "Would a unique index alone fix it, or would you also need to change the insert logic?"
- **Common Mistakes:** Assuming MongoDB somehow prevents duplicate documents by default — it doesn't, without an explicit unique index.
- **What This Tests:** Understanding of classic read-modify-write race conditions in a real, specific code path.
- **Red Flags:** Says "MongoDB handles concurrency automatically" with no specifics.
- **Excellent Answer:** Proposes both changes together: a unique index on `canonical_name` *and* changing `create_profile` to an `update_one(..., upsert=True)` (or a `findOneAndUpdate` with `upsert=True`) so the race resolves to one document deterministically instead of erroring or duplicating.
- **Poor Answer:** Proposes only a unique index without addressing that the current `insert_one` call would then simply throw a duplicate-key error on the loser of the race, which also needs handling.

---

### B8. Why does `frequency` never reset, even when a profile transitions to `ARCHIVED` and back?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Nothing in `memory/decay_engine.py`, `memory/state_machine.py`, or `memory/memory_manager.py` ever sets `frequency` back to a lower value — it's a monotonically increasing counter for the life of the profile document. This means a merchant archived at `frequency=50` and reactivated jumps immediately toward re-qualifying for `PERMANENT` on its very next natural evaluation, since the state machine only looks at the raw frequency number, not "frequency since last reactivation."
- **Follow-ups:** "Is this a bug, or just an unstated design assumption? How would you find out which, without access to whoever wrote it?"
- **Common Mistakes:** Assuming frequency resets on archival without checking, since that would be the "intuitive" behavior.
- **What This Tests:** Willingness to trace actual behavior rather than assume intuitive behavior is what's implemented.
- **Red Flags:** Asserts frequency resets without having verified it against the code.
- **Excellent Answer:** Proposes that this is worth flagging to a product owner as an ambiguous requirement rather than unilaterally "fixing" it, since a reasonable case exists for either behavior (frequency-since-forever vs. frequency-since-reactivation).
- **Poor Answer:** Confidently declares this is either definitely correct or definitely a bug with no acknowledgment of the ambiguity.

---

### B9. `feedback/retraining_queue.py::trigger_retraining_if_needed` marks records `"processing"` and then does nothing further. What state do those records end up in permanently?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** They stay `"processing"` forever — no code anywhere transitions them to `"completed"`, back to `"pending"` on failure, or anywhere else. The `# TODO: Launch BaselineTrainer().run_benchmarks() via Celery asynchronously here` comment marks exactly where the implementation stops. This also means the *next* batch of 100 corrections has to accumulate from zero, since the already-`"processing"` records no longer count toward `check_retraining_status`'s pending count.
- **Follow-ups:** "How would you detect this problem in a running system without reading the source code?" "What would you add to make this self-healing?"
- **Common Mistakes:** Assuming a `"processing"` status implies something is actively running elsewhere — nothing is.
- **What This Tests:** Ability to trace a state machine to its actual terminal (or non-terminal, stuck) states.
- **Red Flags:** Assumes the `TODO` comment means the feature "mostly works, just needs a bit more."
- **Excellent Answer:** Notes you could detect this operationally by monitoring `retraining_queue`'s `"processing"` count over time — a monotonically growing count with no corresponding growth in trained-model artifacts would be the tell.
- **Poor Answer:** No proposed detection method, just restates the code's behavior.

---

### B10. Why is `feedback/api_router.py::submit_feedback`'s retraining check deferred to a `BackgroundTasks` call rather than awaited directly?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** The caller submitting feedback doesn't need to know or wait for whether their specific submission happened to cross a global retraining threshold — that's an unrelated, potentially slower, batch-level concern. Deferring it to `BackgroundTasks` keeps the feedback-submission response fast, at the cost of the caller having zero visibility into whether retraining was actually triggered as a result.
- **Follow-ups:** "What would you do differently if the retraining trigger were actually expensive (e.g., launched real training)?"
- **Common Mistakes:** Not recognizing `BackgroundTasks` still runs in the same process/worker, not a separate queue — a genuinely expensive task here would still compete for the same resources as incoming requests.
- **What This Tests:** Correct understanding of what `BackgroundTasks` actually is and isn't (not a distributed task queue).
- **Red Flags:** Confuses `BackgroundTasks` with Celery or a message queue.
- **Excellent Answer:** Notes that if the missing training-launch step were implemented naively inside this background task, it would risk starving the web server process of resources needed for concurrent requests — which is exactly why the code's own comments reference wanting real Celery integration instead.
- **Poor Answer:** Treats `BackgroundTasks` as equivalent to an external job queue.

---

### B11. Trace what happens if `behaviour/behavior_engine.py::profile_merchant_behavior` is called for a merchant with zero transactions.
- **Difficulty:** Easy | **Importance:** 5
- **Expected Answer:** It raises `ValueError` explicitly, rather than computing and persisting a degenerate all-zero `BehaviorPattern`. This is a deliberate choice to make "we have no data" an explicit, catchable condition distinct from "this merchant genuinely has zero variance in its spending."
- **Follow-ups:** "Where does this exception actually get caught, given nothing currently calls this function automatically?"
- **Common Mistakes:** Assuming a zero-valued `BehaviorPattern` gets written instead.
- **What This Tests:** Reading the actual guard clause rather than assuming graceful degradation everywhere (this codebase does both, inconsistently, depending on the function).
- **Red Flags:** Assumes uniform error-handling behavior across the codebase.
- **Excellent Answer:** Notes that since nothing currently calls this function from the live HTTP path, this exception has likely never actually been exercised in a real running deployment — an important caveat about "correct" code that's never been tested under real conditions.
- **Poor Answer:** Correct about the `ValueError` but no further insight.

---

### B12. `features/amount_features.py::extract_statistical_metrics` and `features/temporal_features.py::extract_temporal_metrics` both have a latent bug. Describe it and explain why it hasn't caused a production incident.
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Both functions' empty-input branches (`n == 0` / no timestamps) return dictionaries with *different key names* than their normal-path branches — e.g., `avg`/`median`/`entropy` vs. `avg_amount`/`median_amount`/`entropy_score`. This would cause a `KeyError` in any caller that indexes with the normal-path keys against an empty-input result. It hasn't caused an incident because `behaviour/behavior_engine.py`, the only caller, already raises `ValueError` on empty transaction lists *before* ever calling these extractors — so the buggy branch is unreachable via the current call path.
- **Follow-ups:** "What would need to change for this bug to actually manifest?"
- **Common Mistakes:** Calling this "not a real bug since it never happens" — it's a real bug that happens to be currently unreachable; a future caller without the same upstream guard would hit it immediately.
- **What This Tests:** Distinguishing "latent" from "nonexistent" — a subtle but important quality-review skill.
- **Red Flags:** Dismisses the bug entirely because "it never triggers."
- **Excellent Answer:** Points out this is exactly the kind of bug that survives code review because it's masked by a caller's defensive check — and would resurface the moment someone reuses these "pure, well-tested" functions from a new call site without replicating that same guard.
- **Poor Answer:** Only identifies the key mismatch without explaining why it's currently dormant.

---

### B13. Why does `rag/retriever.py::fetch_grounded_context` await its three per-merchant lookups sequentially inside a loop, rather than concurrently?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Simplicity of implementation — sequential `await` calls are straightforward to read and reason about. The cost: for `top_k=3` matched merchants, this means up to 9 sequential MongoDB round trips (3 per merchant) contributing directly, in series, to `/v1/explain`'s total latency, when none of the lookups actually depend on each other's results.
- **Follow-ups:** "Write the `asyncio.gather` version of this loop." "Would parallelizing across merchants change any correctness property here?"
- **Common Mistakes:** Assuming this is somehow required because the loop also does other synchronous work — it doesn't; the three lookups within one merchant's iteration, and across merchants, are all independent.
- **What This Tests:** Practical `asyncio` fluency — recognizing genuinely parallelizable I/O and knowing the tool to fix it.
- **Red Flags:** Can't explain what `asyncio.gather` does or when it's appropriate.
- **Excellent Answer:** Notes that parallelizing wouldn't change correctness (each result is independent and order doesn't matter for the final context list), making this a purely additive performance win with no downside beyond slightly more complex code.
- **Poor Answer:** Vague "make it async" without engaging with the fact it's already async, just not concurrent.

---

### B14. `rag/generator.py::generate_explanation` uses both a strict system prompt *and* Ollama's `format: "json"` parameter. Isn't one of these redundant?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** No — they operate at different layers. The system prompt is an instruction-level constraint (the model is *told* to behave a certain way, which it can still fail to follow). `format: "json"` is a decoding-level constraint enforced by Ollama itself, guaranteeing syntactically valid JSON output regardless of what the model "wants" to say. Using both is defense in depth: the prompt aims for good *content* (grounded, non-hallucinated), the format flag guarantees good *syntax*.
- **Follow-ups:** "Does `format: json` guarantee the JSON matches the *specific* schema described in the system prompt?"
- **Common Mistakes:** Assuming `format: "json"` alone is sufficient, missing that it says nothing about which keys or values appear.
- **What This Tests:** Nuanced understanding of prompt engineering vs. structured decoding as genuinely different mechanisms.
- **Red Flags:** Says the two are interchangeable or one is pointless.
- **Excellent Answer:** Correctly notes `format: "json"` guarantees valid JSON *syntax* only — nothing in this codebase validates that the parsed response actually contains the expected keys (`explanation`, `confidence_in_explanation`, `primary_data_source`); a syntactically valid but semantically wrong response would pass through unchecked.
- **Poor Answer:** Doesn't distinguish syntax-level from content-level guarantees.

---

### B15. What's the exact difference between what happens when Milvus returns zero search results versus when Milvus itself is unreachable, in `rag/retriever.py` and `milvus/search_vectors.py`?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Both cases produce the *same observable result* from `find_similar_behaviors`: an empty list. A genuine "no matches" result and a Milvus outage are caught by the same broad `try/except Exception` in `search_vectors.py`, both logged as a warning, both returning `[]`. There is no way for a caller to distinguish "legitimately nothing matched" from "the search itself failed" without reading server logs.
- **Follow-ups:** "Why might that be an acceptable trade-off here, and where would it not be?"
- **Common Mistakes:** Assuming there's a distinct error path for infrastructure failures vs. empty results.
- **What This Tests:** Careful reading of exception-handling scope — many candidates will assume more error granularity exists than actually does.
- **Red Flags:** Confidently describes a distinction that doesn't exist in the code.
- **Excellent Answer:** Argues this is a reasonable trade-off for `/v1/explain` specifically (both cases correctly result in "no grounded context available," which is the right *user-facing* behavior either way), but would be unacceptable for, say, an internal health/monitoring dashboard that needs to distinguish real outages from legitimate empty results.
- **Poor Answer:** Treats the ambiguity as purely a bug with no situational nuance.

---

### B16. Why does `clustering/cluster_engine.py` import `sklearn.cluster.KMeans` when the actual clustering is done by HDBSCAN?
- **Difficulty:** Easy | **Importance:** 3
- **Expected Answer:** It's a dead import — `KMeans` is never referenced anywhere in the file. Likely a leftover from an earlier draft that considered k-means as an algorithm choice before settling on HDBSCAN (which, unlike k-means, doesn't require specifying the number of clusters upfront and can explicitly model noise/outliers).
- **Follow-ups:** "Why might HDBSCAN be preferred over k-means for this specific use case (grouping merchants by behavior)?"
- **Common Mistakes:** Assuming it must be used somewhere subtly, rather than checking.
- **What This Tests:** Comfort identifying and dismissing dead code confidently, backed by an actual grep/check rather than assumption.
- **Red Flags:** Invents a usage for it that doesn't exist in the file.
- **Excellent Answer:** Connects the choice of HDBSCAN specifically to the domain need: the "true" number of natural merchant groupings is unknown ahead of time, and some merchants genuinely don't belong to any coherent group — both of which HDBSCAN handles natively and k-means does not.
- **Poor Answer:** "It's probably used for something else in clustering" without checking.

---

### B17. Name both independent bugs in `clustering/cluster_engine.py` and explain why fixing only one wouldn't make the module functional.
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** (1) `from sklearn.metrics import ... davies_bouldin_index` — the real scikit-learn function is named `davies_bouldin_score`; this raises `ImportError` the moment the module is loaded, before anything else in the file executes. (2) `vector_store.behavior_collection.query(...)` — `VectorStoreManager` (in `milvus/insert_vectors.py`) has no `behavior_collection` attribute at all, only `client` and `behavior_col_name`; this would raise `AttributeError` immediately after the import fix, since it's the very next thing the pipeline does.
- **Follow-ups:** "What's the correct replacement call for the second bug?"
- **Common Mistakes:** Finding only the import error and assuming the module would work after that one fix.
- **What This Tests:** Whether the candidate actually tries to trace execution *past* the first bug found, a habit that separates thorough debugging from surface-level pattern matching.
- **Red Flags:** Stops after identifying the import error.
- **Excellent Answer:** Provides the actual corrected call: something like `vector_store.client.query(collection_name=vector_store.behavior_col_name, expr="id != ''", output_fields=[...])`.
- **Poor Answer:** Identifies only one bug, confidently declares the module "should work" once that's fixed.

---

### B18. `training/train.py` and `training/finetune.py` both claim in docstrings to query real data but actually generate synthetic data. What's the risk of this discrepancy going unnoticed?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Anyone running these scripts and trusting the docstrings would believe the resulting benchmark numbers or fine-tuned model reflect real transaction/feedback patterns, when they actually reflect randomly generated or hand-picked mock data repeated hundreds of times. This could lead to false confidence in a model's readiness, or wasted effort tuning hyperparameters against data that doesn't represent production reality at all.
- **Follow-ups:** "How would you verify a training script's data source without running it?"
- **Common Mistakes:** Assuming a docstring accurately describes current behavior — a fair default assumption in a mature codebase, but not one that holds here.
- **What This Tests:** Whether the candidate treats documentation as a starting hypothesis to verify, not ground truth.
- **Red Flags:** Takes the docstring's claim at face value without checking `load_data()`'s actual implementation.
- **Excellent Answer:** Notes that reading `load_data()`'s body directly (`np.random.exponential`, `np.random.choice`, etc.) takes seconds and immediately reveals the discrepancy — a habit worth applying to every "intended behavior" claim in any codebase, not just this one.
- **Poor Answer:** Trusts the docstring's description as accurate.

---

### B19. Why does `evaluation/metrics.py::generate_shap_importances` need three separate code branches to extract SHAP values?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Different SHAP explainer/model combinations and different library versions return values in inconsistent shapes: a list of per-class arrays, a single 3D array, or a flat 2D array. The function normalizes all three into one consistent per-feature importance vector so callers don't need to know or handle which shape a given model/library version produced.
- **Follow-ups:** "What happens if a fourth, unhandled shape appears from a future SHAP version?"
- **Common Mistakes:** Assuming this complexity is unnecessary defensive coding rather than a real response to genuine API inconsistency in the SHAP library across versions and explainer types.
- **What This Tests:** Recognizing that some apparent "over-engineering" is actually justified by real upstream inconsistency.
- **Red Flags:** Suggests removing the branching "for simplicity" without acknowledging why it exists.
- **Excellent Answer:** Notes the function's broad `try/except` around the whole SHAP computation is the actual safety net for the "fourth unhandled shape" scenario — it logs a warning and returns `{}` rather than crashing the whole training run.
- **Poor Answer:** No engagement with why the branching exists.

---

### B20. In `graphs/graph_builder.py::build_graph`, why are `Behavior`/`Cluster`/`Feedback` nodes only added if the corresponding merchant node already exists?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** To preserve graph integrity — a behavior record or feedback event references a merchant by name string, and if that merchant was never processed through the memory engine (no `merchant_profiles` document, hence no graph node), attaching data to a non-existent, unverified entity would create orphaned nodes with no real identity backing them.
- **Follow-ups:** "What real-world scenario would cause a behavior_patterns document to exist for a merchant with no corresponding profile?"
- **Common Mistakes:** Assuming every `behavior_patterns` document automatically has a corresponding `merchant_profiles` document — nothing enforces this relationship (see `docs/18-database-analysis.md`).
- **What This Tests:** Connecting a specific code guard back to the broader lack-of-referential-integrity problem across the whole system.
- **Red Flags:** Treats the guard as arbitrary rather than a deliberate integrity check.
- **Excellent Answer:** Constructs a realistic scenario: someone manually invokes `behaviour/behavior_engine.py::profile_merchant_behavior` for a merchant name that was never routed through `/memory/update` — since nothing enforces that `merchant_profiles` and `behavior_patterns` share entities, this is entirely possible today.
- **Poor Answer:** Describes the guard's mechanics without explaining the underlying data-integrity motivation.

---

### B21. Why is `scripts/mock_seeder.py`'s cleanup function filtered on both `user_id` and `is_mock`, rather than just `user_id`?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** Defense in depth — if `user_123` ever legitimately had real, non-mock transactions for any reason, a blanket delete filtered only by `user_id` would destroy them too. Requiring both conditions ensures cleanup only ever removes data this exact script created.
- **Follow-ups:** "Contrast this with `scripts/seed.py`'s approach to its own data."
- **Common Mistakes:** Not noticing `scripts/seed.py` does the opposite — an unconditional `delete_many({})` on the entire `merchants` collection before reseeding, with no equivalent safety filter.
- **What This Tests:** Comparative code review — noticing an inconsistency in safety practices between two superficially similar scripts.
- **Red Flags:** Doesn't compare the two scripts when explicitly relevant.
- **Excellent Answer:** Explicitly flags that `seed.py`'s blanket delete is comparatively unsafe and should adopt a similar targeted-filter or upsert-based approach instead.
- **Poor Answer:** Only describes `mock_seeder.py` in isolation.

---

### B22. What would happen if `routers/observability.py::trigger_drift_analysis` were called 1,000 times in a row?
- **Difficulty:** Easy | **Importance:** 3
- **Expected Answer:** Nothing different from calling it once — it's a pure, stateless stub that returns the exact same fixed dict every time, with zero side effects, zero I/O, and no accumulation of any kind.
- **Follow-ups:** "How would this behavior mislead an operator who doesn't know it's a stub?"
- **Common Mistakes:** Assuming repeated calls might trigger rate limiting or some cumulative effect specific to this endpoint.
- **What This Tests:** Recognizing a genuinely trivial, side-effect-free function for what it is, without over-analyzing.
- **Red Flags:** Invents behavior (like queued jobs) that doesn't exist in the code.
- **Excellent Answer:** Connects this to the operational risk: an operator or automated system calling this repeatedly and seeing `"status": "success"` every time would have no way to know nothing real is happening — a false-confidence risk distinct from the code's own (lack of) behavior.
- **Poor Answer:** Only describes the mechanical repetition without the operational-risk angle.

---

### B23. `services/merchant_resolver.py::clean_text` uppercases all text before comparison. What would break if a caller forgot this convention when seeding new merchant aliases?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** `scripts/seed.py`'s aliases are already stored in uppercase (matching the convention), but if a new alias were added in mixed or lowercase, it would never match, since `find_one({"aliases": cleaned_text})` does an exact-value match against the (always-uppercase) cleaned input — MongoDB won't case-fold this automatically without a case-insensitive index or query. The substring fallback *does* use `$options: "i"` for case-insensitivity, but the exact-match check does not.
- **Follow-ups:** "Why might the exact-match check lack the same case-insensitivity the substring check has?"
- **Common Mistakes:** Assuming both the exact-match and substring queries are equally case-insensitive — only the substring one explicitly is.
- **What This Tests:** Close reading of two superficially similar queries in the same function that actually behave differently.
- **Red Flags:** Assumes uniform behavior across both matching strategies without checking each individually.
- **Excellent Answer:** Proposes storing and always comparing aliases in a normalized case (as the codebase already effectively does by convention) or adding case-insensitive collation to the exact-match query for genuine robustness against a future data-entry mistake.
- **Poor Answer:** Doesn't notice the exact-match query lacks case-insensitivity at all.

---

### B24. Why does `analytics/anomaly_detection.py::flag_transaction` treat `std_dev == 0` as "insufficient data" instead of flagging any deviation as an infinite-sigma anomaly?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** A merchant with zero historical variance (e.g., always charges exactly the same amount) hasn't demonstrated any variability at all — computing a z-score would either divide by zero or produce a statistically meaningless "infinite" anomaly signal for any different amount, however small the difference. Treating this as "insufficient baseline" is the more honest and numerically safe response.
- **Follow-ups:** "What's a real merchant scenario where this guard clause matters?"
- **Common Mistakes:** Suggesting the guard is purely defensive against a crash, missing the statistical-meaninglessness argument.
- **What This Tests:** Statistical reasoning applied to a specific, small piece of business logic.
- **Red Flags:** Only mentions "prevents division by zero" without the deeper statistical justification.
- **Excellent Answer:** Gives a concrete example: a subscription service that always charges exactly ₹499 — the very first month it charges ₹500 instead (a plausible price change) shouldn't be treated as an infinitely-confident anomaly; "insufficient baseline" correctly defers judgment until more data accumulates.
- **Poor Answer:** Only cites the division-by-zero risk.

---

### B25. If you had one hour to improve code quality in this backend with the biggest overall impact, which single change would you make, and why?
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** There's no single universally correct answer, but a strong candidate answer centers on either (a) fixing `repositories/profile_repository.py`'s missing `Optional` import, since it likely blocks the entire application from starting, making every other improvement moot until it's fixed, or (b) adding a CI check that verifies every `router` defined in `routers/*.py` (and `feedback/api_router.py`) is actually mounted in `app.py`, since that single class of bug (defined-but-unmounted, or defined-but-uncalled) explains a large fraction of this codebase's disconnected features.
- **Follow-ups:** "Defend your choice against someone who argues for fixing `POST /v1/categorize` instead."
- **Common Mistakes:** Picking a locally interesting but low-blast-radius fix (e.g., a dead import) over something that unblocks the whole system or prevents a whole class of future bugs.
- **What This Tests:** Prioritization judgment — the hallmark difference between a mid-level and senior engineer is choosing impact over interestingness.
- **Red Flags:** Picks a cosmetic fix (unused import removal) as "highest impact."
- **Excellent Answer:** Explicitly reasons about blast radius and reversibility: the `Optional` import fix is a one-line, zero-risk change that potentially unblocks the entire application, making it both maximally impactful *and* maximally safe — the ideal combination for a time-boxed improvement.
- **Poor Answer:** Picks something interesting but low-impact (e.g., "I'd remove the unused `KMeans` import") without weighing it against higher-leverage options.
