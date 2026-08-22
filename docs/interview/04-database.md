# Database — 25 Questions

---

### D1. How many databases does this system actually use, and why does that matter for anyone new to the codebase?
- **Difficulty:** Easy | **Importance:** 7
- **Expected Answer:** Two — MongoDB (system of record) and Milvus (vector similarity search) — plus Ollama, which isn't a database but is architecturally treated like one in the request flow (an awaited external dependency the handler can't proceed without). New engineers often assume "the database" is singular and miss that data consistency, connection management, and failure modes need to be reasoned about independently for each.
- **Follow-ups:** "Which of the three has the most permissive failure handling, and which the least?"
- **Common Mistakes:** Referring to "the database" singular throughout a design discussion, implicitly forgetting Milvus exists.
- **What This Tests:** Basic system inventory accuracy — surprisingly often missed.
- **Red Flags:** Says "MongoDB" only, forgetting Milvus or Ollama's role entirely.
- **Excellent Answer:** Notes that `database/milvus.py`'s Milvus client degrades gracefully (returns `None` after retries) while `core/ollama_client.py`'s resolution can crash the whole process — genuinely different failure philosophies for what a system diagram would draw as three equivalent "external dependency" boxes.
- **Poor Answer:** Names only MongoDB.

---

### D2. How many indexes exist across all of this system's MongoDB collections?
- **Difficulty:** Easy | **Importance:** 9
- **Expected Answer:** Zero, beyond the automatic `_id` index every collection gets by default. Verified by grepping the entire codebase for `create_index` calls against Mongo — the only index anywhere in either database is Milvus's HNSW vector index. Every single MongoDB query in this application — every `find_one`, every aggregation `$match` — runs as a full collection scan.
- **Follow-ups:** "Which three indexes would you add first, and on what basis would you prioritize?"
- **Common Mistakes:** Assuming MongoDB automatically indexes frequently-queried fields, or assuming *some* indexes must exist because the app "seems to work fine" at small scale.
- **What This Tests:** Willingness to state a stark, uncomfortable fact plainly rather than hedging — and whether the candidate actually checked rather than assumed.
- **Red Flags:** Guesses "probably a few key indexes exist" without a definitive answer.
- **Excellent Answer:** Prioritizes a unique index on `merchant_profiles.canonical_name` first (fixes both a performance problem *and* the duplicate-profile race condition from a single change), then `behavior_patterns.merchant_name`, then a compound `{user_id, timestamp}` on `transactions`.
- **Poor Answer:** Vague "add indexes where needed" with no specific field names.

---

### D3. Describe the `feedback.prediction` field bug — what it's supposed to hold, what it actually holds, and the concrete consequence.
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** `feedback/feedback_service.py::process_feedback` writes `"prediction": original_prediction`, and both the request model and `test_api.py`'s own test data confirm this holds a category string (e.g., `"Unknown"`, `"Travel"`) — not a merchant name. But `rag/retriever.py` queries `db.feedback.find({"prediction": name})` where `name` is a *merchant* name (`"Swiggy"`), and `graphs/graph_builder.py` checks `merchant_prediction in self.graph` (a graph of merchant nodes) using that same field. Since category strings essentially never coincide with merchant names, both consumers silently receive almost no data: the RAG pipeline's human-correction context is starved even when directly relevant feedback exists, and nearly every feedback node in the knowledge graph fails to attach anywhere.
- **Follow-ups:** "Why did nothing catch this — no test, no exception, no error log?" "What's the minimal fix?"
- **Common Mistakes:** Confusing this with the *separate* category-vocabulary mismatch bug (`TransactionCategory` enum vs. `merchant_aliases.json`'s categories) — these are two distinct, unrelated defects.
- **What This Tests:** Whether the candidate can hold two collections' actual, verified field semantics in mind simultaneously and notice they don't match a third module's assumption — a genuinely hard, cross-file bug-finding skill.
- **Red Flags:** Can't articulate *why* this fails silently rather than throwing an error (because a `find`/`in` check against no matches is a normal, valid outcome, not an exception).
- **Excellent Answer:** Proposes the fix precisely: add a real `merchant_name` field to the `feedback` document at write time (threaded in from whatever categorized the original transaction), and update both read sites to query on it instead of `prediction`.
- **Poor Answer:** Vaguely says "the feedback data doesn't line up" without identifying the specific field or the specific consuming files.

---

### D4. Why do `merchants` and `merchant_profiles` exist as two separate collections, and is that a problem?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** They represent overlapping concepts (canonical merchant identity) built by different phases (`merchants` by Phase 3's resolver, `merchant_profiles` by Phase 4's memory engine) with zero code path reading or writing both. `services/merchant_resolver.py` only ever touches `merchants`; `memory/memory_manager.py` and `repositories/profile_repository.py` only ever touch `merchant_profiles`. A merchant resolved via `/v1/resolve` is never automatically registered in the memory system, and vice versa.
- **Follow-ups:** "How would you unify these without a disruptive migration?" "Which one should be the 'source of truth'?"
- **Common Mistakes:** Assuming they're synchronized because they logically should be, without checking for actual code connecting them (there is none).
- **What This Tests:** Cross-referencing two similarly-purposed collections and correctly concluding they're disconnected, not just redundant.
- **Red Flags:** Assumes a sync mechanism exists without verifying.
- **Excellent Answer:** Proposes a phased consolidation: make `merchant_profiles` the canonical identity store (since it already tracks richer state), have `/v1/resolve` write/update a `merchant_profiles` entry on every resolution instead of querying the separate `merchants` collection, and migrate `merchants`' seed data into `merchant_profiles.aliases`.
- **Poor Answer:** Suggests simply "merging the collections" without addressing the different access patterns each currently serves.

---

### D5. Why does `repositories/profile_repository.py::get_profile` project out `_id` with `{"_id": 0}`?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It simplifies constructing a `MerchantProfile` from the raw document without needing to handle Mongo's `_id`-to-`id` alias mapping on every read. The cost: it permanently discards the document's real identifier from the API's perspective — every profile fetched this way reports `id: None`, even though a real `_id` exists in the underlying document.
- **Follow-ups:** "What would you lose if a client actually needed a stable identifier for a profile?"
- **Common Mistakes:** Assuming `id: None` in the API response means the document has no real MongoDB `_id` — it does; it's just never surfaced.
- **What This Tests:** Distinguishing "the field is absent in the response" from "the underlying data doesn't exist."
- **Red Flags:** Conflates "not returned" with "doesn't exist in the database."
- **Excellent Answer:** Notes this becomes a real limitation if a future feature needs to reference a specific profile by a stable ID (e.g., a direct link in a UI) — `canonical_name` is currently the only usable identifier, which works today but conflates "identity" with "display name" in a way that would break if a merchant were ever renamed.
- **Poor Answer:** Describes the projection mechanically without discussing the consequence.

---

### D6. Walk through why `analytics/subscriptions.py`'s aggregation pipeline can return `last_amount`/`last_seen` values that aren't actually the most recent.
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** The pipeline uses `$group` with `$last`/`$max` accumulators, but there's no `$sort` stage before the `$group` — MongoDB doesn't guarantee document order into a `$group` without an explicit prior sort, so `$last` could reflect any document in the group's original (arbitrary, storage-order-dependent) sequence, not necessarily the chronologically last one.
- **Follow-ups:** "Write the corrected pipeline." "Would this bug be easy to catch in a code review, and why or why not?"
- **Common Mistakes:** Assuming MongoDB always processes documents in insertion order by default — it doesn't guarantee this for aggregation pipeline stages without explicit sorting.
- **What This Tests:** Deep, correct understanding of MongoDB aggregation semantics, not just surface familiarity with the operators.
- **Red Flags:** Assumes `$last` inherently means "most recently inserted" without qualification.
- **Excellent Answer:** Provides the fix: insert `{"$sort": {"timestamp": 1}}` immediately before the `$group` stage — and notes this bug is genuinely easy to miss in review because the code *reads* as if it's doing the right thing; only someone who knows this specific MongoDB gotcha would catch it without testing.
- **Poor Answer:** Identifies "something's wrong with ordering" without pinpointing the missing `$sort` specifically.

---

### D7. Why does `behaviour/behavior_engine.py` use `upsert=True` while `repositories/profile_repository.py::create_profile` uses a plain `insert_one`?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** `behavior_engine` always recomputes the *entire* `BehaviorPattern` from source transaction data on every call, so whether a document already exists or not, the correct action is "replace it entirely" — `upsert=True` handles both the first-time and subsequent-time cases identically and correctly. `create_profile` is only ever called after `get_profile` has already confirmed no profile exists, so a plain insert is logically sufficient *in the single-request case* — but as discussed elsewhere, this exact assumption breaks under concurrent requests (see Backend B7).
- **Follow-ups:** "Would changing `create_profile` to an upsert fully fix the race condition from B7, or just some of it?"
- **Common Mistakes:** Assuming `upsert` and plain `insert` are just stylistic choices with no functional difference.
- **What This Tests:** Connecting a data-access-pattern question to a previously-discussed concurrency bug — testing whether understanding transfers across question boundaries.
- **Red Flags:** Treats the two write patterns as arbitrary/interchangeable.
- **Excellent Answer:** Notes that switching `create_profile` to `update_one(..., upsert=True)` would resolve the race to "last write wins on one document" rather than "two documents created" — better, but still not fully safe without a version-checked conditional update if losing an increment matters.
- **Poor Answer:** Doesn't connect this to the earlier concurrency discussion at all.

---

### D8. What does it mean that `behavior_patterns.discovered_cluster` is written by `clustering/cluster_engine.py` but doesn't exist in the `BehaviorPattern` Pydantic model?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** MongoDB is schemaless, so a second writer can add a field the original model never declared, and it will persist and be readable by raw dict access (as `graphs/graph_builder.py` does) without any validation or even documentation in `models/schemas.py`. This is legitimate schema evolution in a document store, but it's a maintainability gap: a future engineer reading the Pydantic model alone would have no idea this field exists on real documents.
- **Follow-ups:** "How would you retroactively document or formalize this?"
- **Common Mistakes:** Assuming Pydantic models constrain what can actually be stored in MongoDB — they only constrain what passes through code paths that use that specific model for validation.
- **What This Tests:** Correct mental model of "schema" in a document database — advisory at the application layer, not enforced at the storage layer.
- **Red Flags:** Assumes the Pydantic model is an enforced database schema.
- **Excellent Answer:** Proposes adding `discovered_cluster: Optional[str] = None` to the `BehaviorPattern` model as a low-risk, purely additive fix that documents reality without changing behavior (Pydantic ignores or accepts extra fields depending on config, but declaring it explicitly makes the contract honest).
- **Poor Answer:** Says this "shouldn't be allowed" without acknowledging it's a normal, valid MongoDB pattern, just an undocumented one here.

---

### D9. Explain the difference between a "hard" and "soft" relationship in this system's data model, with one real example of each.
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** A "hard" relationship is one actually exercised by a real query — e.g., `transactions.merchant` to `behavior_patterns.merchant_name` via a real `$lookup` in `analytics/subscriptions.py`. A "soft" relationship exists only by naming convention with no code enforcing or even traversing it — e.g., `feedback.transaction_id` is a free-text string never validated against any real `transactions._id`; nothing prevents (or even notices) a `feedback` document pointing at a transaction that doesn't exist.
- **Follow-ups:** "How would you tell the difference between the two just by reading a Pydantic model, without checking the actual queries?"
- **Common Mistakes:** Assuming any field with a suggestive name (`transaction_id`, `merchant_name`) implies an enforced relationship.
- **What This Tests:** Whether the candidate distinguishes "looks like a foreign key" from "is actually queried/joined as one" — you truly cannot tell from the schema alone in a document database.
- **Red Flags:** Says you can tell from the model definition whether a relationship is enforced.
- **Excellent Answer:** Explicitly states you *cannot* determine this from `models/schemas.py` alone — you have to trace actual query call sites, which is exactly the kind of verification this whole documentation effort did to distinguish real joins from decorative field names.
- **Poor Answer:** Gives one example without generalizing the hard/soft distinction.

---

### D10. Why does `feedback/feedback_service.py`'s write to `feedback` and (conditionally) `retraining_queue` represent a real correctness risk, even though both are simple `insert_one` calls?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** They're two independent, non-atomic operations with no MongoDB session/transaction wrapping them (verified — no `start_session`/`with_transaction` exists anywhere in this codebase). A crash or network failure between the two leaves a correction permanently logged in `feedback` but never queued for retraining, with no reconciliation job to detect or repair the gap.
- **Follow-ups:** "Would a multi-document transaction be the right fix here, or is there a simpler alternative?"
- **Common Mistakes:** Assuming two sequential `insert_one` calls in the same function are "basically atomic" because they're written next to each other.
- **What This Tests:** Recognizing that code proximity has nothing to do with atomicity guarantees.
- **Red Flags:** Says "it's fine, they're both in the same function" as if that implies transactional safety.
- **Excellent Answer:** Proposes a simpler alternative to a full transaction: make the retraining queue reconcilable from `feedback` alone (e.g., a periodic job that finds corrections in `feedback` not yet represented in `retraining_queue`), which avoids the complexity of distributed transactions while still closing the gap.
- **Poor Answer:** Proposes only "wrap it in a transaction" without weighing the complexity trade-off against reconciliation.

---

### D11. The `categories` MongoDB collection is created on every app startup. What's actually in it?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** Nothing, ever — it's a completely dead collection. It's declared in `database/mongo.py::MongoDB.connect` alongside the six actually-used collections, but no module anywhere reads from or writes to it. `models/schemas.py::Category` exists as a Pydantic model but is never instantiated outside its own declaration.
- **Follow-ups:** "How would you verify this claim in under a minute?"
- **Common Mistakes:** Assuming a collection's existence in `MongoDB.connect` implies active use somewhere in the codebase.
- **What This Tests:** Willingness to verify "this exists, so it must be used" assumptions with an actual search rather than accepting them.
- **Red Flags:** Assumes it's used without checking.
- **Excellent Answer:** Describes the verification method precisely: grep the codebase for `db.categories` and `Category(` — zero hits beyond the declaration itself confirms it's dead.
- **Poor Answer:** Correct conclusion, no described verification method.

---

### D12. What's the Milvus equivalent of a MongoDB index, and is it configured well for this system's current scale?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Milvus's HNSW index (configured in `milvus/insert_vectors.py::_ensure_collections`, `metric_type=COSINE`, `M=8`, `efConstruction=200`) serves an analogous role — enabling fast approximate nearest-neighbor search instead of a brute-force scan over every stored vector. The parameters chosen are reasonable, standard defaults appropriate for a small-to-moderate vector count; they would likely need retuning (higher `M`/`efConstruction`, or a move to Milvus's distributed/cluster mode) if the vector count grew into the millions.
- **Follow-ups:** "What would happen to search quality if you lowered `ef` at query time?"
- **Common Mistakes:** Assuming vector databases don't need "indexes" in the traditional sense, or not knowing HNSW is itself an indexing structure.
- **What This Tests:** Cross-domain database knowledge — applying the "index" concept correctly to a non-relational, non-document data structure.
- **Red Flags:** Says vector search "doesn't use indexes."
- **Excellent Answer:** Connects the `ef` parameter (used at query time in `milvus/search_vectors.py`'s `search_params`) to the classic speed/recall trade-off inherent to approximate nearest-neighbor search — lower `ef` means faster but less accurate search.
- **Poor Answer:** Correctly names HNSW but can't explain what any of its parameters actually control.

---

### D13. Why is the vector dimensionality (`VECTOR_DIM = 768`) hardcoded in `milvus/insert_vectors.py`, and what happens if it's wrong?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** It must match whatever embedding model `EMBED_MODEL` (via Ollama) actually produces — nothing in the codebase validates this correspondence at runtime. If `EMBED_MODEL` were changed to a model with a different output dimensionality, insertion or search calls would fail with a dimension-mismatch error from Milvus itself, not a clear, early validation error from this codebase.
- **Follow-ups:** "Where would you add a validation check for this, and what would it check against?"
- **Common Mistakes:** Assuming Milvus or Ollama would somehow negotiate or auto-detect the correct dimension.
- **What This Tests:** Understanding that cross-system configuration consistency (a model's actual output shape vs. a downstream system's hardcoded expectation) is a real, unvalidated risk here.
- **Red Flags:** Assumes this is automatically handled.
- **Excellent Answer:** Proposes a one-time startup check: call `embedding_generator.generate("test")` once at startup, check `len(result) == VECTOR_DIM`, and fail fast with a clear error if they don't match — rather than surfacing as a cryptic Milvus error deep in a request path.
- **Poor Answer:** Identifies the risk without proposing where or how to validate it.

---

### D14. If you were asked to add multi-tenancy to this database layer, which collections would need a `user_id`/`tenant_id` field added, and which already have one?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** `transactions` already has `user_id` (though hardcoded to `"user_123"` everywhere it's used). `feedback` has `user_id` but it's always `"system_user"` — never a real caller identity. `merchant_profiles`, `behavior_patterns`, and `merchants` currently have **no** tenant scoping at all — they're modeled as globally shared entities, which may or may not be the correct design depending on whether merchant identity/behavior should be shared across tenants or isolated per tenant (a genuine product decision, not just a technical one).
- **Follow-ups:** "Should merchant identity be shared across tenants, or per-tenant? What are the trade-offs either way?"
- **Common Mistakes:** Assuming every collection needs a `tenant_id` uniformly, without considering that shared reference data (like a canonical "Swiggy" merchant) might legitimately be tenant-agnostic.
- **What This Tests:** Product-aware database design thinking — not every multi-tenancy problem has the same shape.
- **Red Flags:** Proposes adding `tenant_id` to every collection without discussing which should actually be shared.
- **Excellent Answer:** Argues for a split model: `transactions`/`feedback`/`merchant_profiles`' trust-state fields as tenant-scoped, but `merchants`' canonical alias data potentially shared globally across tenants (since "Swiggy" means the same thing to every tenant) — with careful reasoning about which fields on `merchant_profiles` specifically would need to become per-tenant (e.g., `frequency`, `memory_state` are inherently about *this tenant's* interaction history).
- **Poor Answer:** Generic "add tenant_id everywhere" with no domain reasoning.

---

### D15. Why does `graphs/graph_builder.py::build_graph` do three full, unfiltered collection scans on every single call?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** It fetches *all* documents from `merchant_profiles`, `behavior_patterns`, and `feedback` with no filter, no projection, no pagination, materializing each into a full Python list before processing begins. This means the graph-building cost scales directly with total row counts across three collections combined, every time it's called — and it's never incremental.
- **Follow-ups:** "How would you make this incremental instead of a full rebuild every time?"
- **Common Mistakes:** Assuming this is acceptable because "it's just building an in-memory graph" without considering the underlying database read cost.
- **What This Tests:** Recognizing that "in-memory computation" doesn't mean "cheap" when the input side involves unbounded database reads.
- **Red Flags:** Focuses only on the graph construction cost, ignoring the database read cost that precedes it.
- **Excellent Answer:** Proposes tracking a `last_graph_build_timestamp` and only fetching documents modified since then, incrementally updating the existing `nx.DiGraph` rather than clearing and rebuilding it from scratch — a genuinely more scalable design.
- **Poor Answer:** Suggests adding indexes as the fix, missing that the query has no filter at all for an index to help with.

---

### D16. What would a MongoDB `$jsonSchema` validator on the `merchant_profiles` collection actually prevent, given this codebase's current behavior?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** It would reject, at the database layer, any insert/update that doesn't match the declared shape — e.g., a `frequency` of `-5`, a `memory_state` outside the four valid enum values, or a document missing `canonical_name` entirely. Currently, none of these are prevented anywhere except by the Pydantic model's type checking, which only applies to code paths that actually construct a `MerchantProfile` object before writing — any raw dict write (which doesn't happen for this particular collection today, but could in future code) would bypass that protection entirely.
- **Follow-ups:** "Is this worth adding given only one code path (the repository) currently writes to this collection?"
- **Common Mistakes:** Assuming Pydantic validation and database-level `$jsonSchema` validation serve redundant purposes — they protect against different failure modes (application bugs vs. any future/external write bypassing the application layer entirely).
- **What This Tests:** Defense-in-depth thinking — validating data correctness at more than one layer.
- **Red Flags:** Dismisses `$jsonSchema` validators as unnecessary "since Pydantic already validates."
- **Excellent Answer:** Argues it's genuinely valuable specifically *because* `merchant_profiles` is the one collection with an existing repository abstraction — adding database-level validation here would be low-effort and would guard against a future refactor accidentally introducing a raw, unvalidated write path.
- **Poor Answer:** Treats database-level and application-level validation as interchangeable.

---

### D17. Why does `services/merchant_resolver.py`'s substring-match query (`$regex: "^word"`) not pose a NoSQL injection risk, even though `word` comes from user-supplied text?
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** Because `clean_text` runs *before* the text is split into words, and `clean_text`'s `special_chars_regex` (`[^a-zA-Z0-9\s]`) strips every character that isn't alphanumeric or whitespace — so by the time `word` is interpolated into the `$regex` pattern, it can only ever contain letters and digits, none of which are regex metacharacters. The injection surface is closed by upstream sanitization, not by any explicit escaping at the query-construction site itself.
- **Follow-ups:** "What would happen if `clean_text` were ever refactored and this ordering broke?" "Is this a robust design, or a fragile accident?"
- **Common Mistakes:** Reflexively flagging this as an injection vulnerability just because user input reaches a `$regex` query, without actually tracing whether the input is sanitized first.
- **What This Tests:** Whether the candidate can reason precisely about a *specific* code path rather than pattern-matching "user input + regex query = vulnerability" without verification — a genuinely important distinction between security theater and real security review.
- **Red Flags:** Confidently declares this an injection vulnerability without tracing `clean_text`'s actual behavior first.
- **Excellent Answer:** Explicitly calls this "fragile-but-currently-safe" — the safety depends entirely on `clean_text` running first and stripping all non-alphanumeric characters; if a future refactor reordered these operations, or added a new call site that skipped `clean_text`, the injection surface would reopen silently with no test currently in place to catch that regression.
- **Poor Answer:** Either wrongly claims it's vulnerable, or claims it's "obviously safe" without explaining the specific sanitization mechanism that makes it so.

---

### D18. What does "the phases are loosely coupled by MongoDB collection boundaries" mean, and why is it actually a scalability strength despite the system's many disconnected features?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Each phase reads/writes specific collections rather than calling into each other's Python code directly (e.g., `analytics/` reads `behavior_patterns` without ever importing anything from `behaviour/`) — meaning several phases (behavior profiling, clustering, training) could become independent workers or services consuming from the same MongoDB collections with comparatively little redesign, once the currently-broken/disconnected pieces are fixed. The coupling that exists is data-shape coupling, not code-level coupling.
- **Follow-ups:** "What would need to change to actually extract `behaviour/` into a separate service today?"
- **Common Mistakes:** Assuming "disconnected" and "poorly architected for scaling" are the same thing — they're not; disconnection at the *wiring* level doesn't imply disconnection at the *architecture* level.
- **What This Tests:** Ability to see past a system's current defects to its underlying structural potential — a mark of senior-level architectural judgment.
- **Red Flags:** Conflates "many features aren't wired up" with "the architecture doesn't support scaling."
- **Excellent Answer:** Notes this is genuinely good news for a future rewrite: extracting `behaviour/behavior_engine.py` into a separate worker process would require almost no change to its actual logic, since it already only talks to MongoDB, not to any in-process Python object from another phase.
- **Poor Answer:** Doesn't distinguish this from the system's other, more concerning problems.

---

### D19. Why would sharding `transactions` on `{user_id: 1}` be a reasonable first step, but sharding on `{_id: 1}` (the default) would not help query performance at all?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Every real query against `transactions` filters by `user_id` (`$match: {user_id: ...}`) — sharding on that field means a query for one user's data can be routed to a single shard rather than scattered across all of them. Sharding on `_id` (an auto-generated ObjectId with no relationship to query patterns) would distribute data evenly but provide zero query-routing benefit, since no query filters by `_id` ranges.
- **Follow-ups:** "What's the risk of sharding on `user_id` directly (not hashed) if one user has vastly more transactions than others?"
- **Common Mistakes:** Assuming any shard key improves performance as long as it distributes data evenly — distribution and query-routing efficiency are different concerns.
- **What This Tests:** Understanding that shard key selection must be driven by actual query patterns, not just data distribution.
- **Red Flags:** Picks a shard key based purely on "spreads data evenly" reasoning.
- **Excellent Answer:** Raises the "hot shard" risk directly: an unhashed `user_id` shard key could create a hotspot if one user generates disproportionately more transactions than others, and proposes a hashed shard key on `user_id` as a mitigation that preserves query-routing benefits while avoiding uneven load.
- **Poor Answer:** Picks `user_id` correctly but can't explain the hotspot risk when asked the follow-up.

---

### D20. Why does `analytics/spending_patterns.py::get_merchant_frequency` have no time-window filter, while its sibling `get_category_breakdown` does?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It's an inconsistency in the API/query design, not a technical necessity — nothing prevents adding a date range to the merchant-frequency query. It may reflect an implicit assumption that "who do I visit most, ever" is a more useful all-time question than a windowed one, but this isn't stated anywhere and the resulting endpoint always scans the user's *entire* transaction history, growing more expensive indefinitely as that history grows, unlike its sibling.
- **Follow-ups:** "How would you retrofit an optional time window without breaking existing callers?"
- **Common Mistakes:** Assuming the omission was a deliberate, principled choice rather than checking whether it might just be an oversight.
- **What This Tests:** Comparing two similar functions and noticing an unexplained asymmetry — a real-world code review skill.
- **Red Flags:** Invents a plausible-sounding justification without acknowledging it isn't actually documented anywhere in the code.
- **Excellent Answer:** Proposes adding an optional `days` parameter defaulting to `None` (preserving current all-time behavior for existing callers) that, when provided, adds the same `$match: {timestamp: {$gte: ...}}` stage the category-breakdown endpoint already uses.
- **Poor Answer:** Doesn't propose a concrete, backward-compatible fix.

---

### D21. Explain precisely what "no read preference is configured" means for this application's MongoDB client, and why it matters.
- **Difficulty:** Hard | **Importance:** 5
- **Expected Answer:** `AsyncIOMotorClient(uri)` in `database/mongo.py` is constructed with no explicit `read_preference` argument, so it uses the Motor/PyMongo default (`primary`) — every read, including read-heavy analytics aggregations, goes to the primary node even if the deployment has replica set secondaries available. This means read load can't be offloaded to secondaries without an explicit code or connection-string change (`readPreference=secondaryPreferred`), and the primary bears 100% of both read and write load.
- **Follow-ups:** "What would be the risk of blindly setting `secondaryPreferred` for every query in this codebase?"
- **Common Mistakes:** Assuming a replica set automatically load-balances reads across nodes without any client configuration.
- **What This Tests:** Understanding that replica set topology alone doesn't provide read scaling — it requires explicit driver configuration.
- **Red Flags:** Assumes read scaling happens "automatically" with a replica set.
- **Excellent Answer:** Correctly identifies that blindly applying `secondaryPreferred` everywhere would introduce read-your-writes staleness risk specifically for `memory/memory_manager.py`'s read-modify-write pattern (reading a profile immediately after writing it) — this should be applied selectively to genuinely read-heavy, staleness-tolerant paths like analytics, not universally.
- **Poor Answer:** Proposes a blanket read-preference change with no consideration of which queries can tolerate staleness.

---

### D22. If `merchant_profiles.canonical_name` had a unique index added today, what existing code would need to change to avoid breaking on the first duplicate?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** `repositories/profile_repository.py::create_profile`'s plain `insert_one` would need to become an `update_one(..., upsert=True)` or be wrapped in a duplicate-key-error catch, since the current code assumes (correctly, only in the non-concurrent case) that `get_profile` having returned `None` means it's always safe to insert — a unique index would turn the race condition from "silent data duplication" (bad, but doesn't crash) into "an unhandled `DuplicateKeyError` exception" (loud, but currently uncaught anywhere in `memory/memory_manager.py::process_encounter`).
- **Follow-ups:** "Is turning a silent bug into a loud one, by itself, actually progress?"
- **Common Mistakes:** Assuming adding the index alone is a strictly additive, risk-free improvement.
- **What This Tests:** Recognizing that a partial fix (index without corresponding code change) can trade one failure mode for a worse one (silent duplication → unhandled crash) if not done together.
- **Red Flags:** Recommends adding the unique index in isolation without mentioning the `create_profile` change that must accompany it.
- **Excellent Answer:** Explicitly argues yes, it is progress even before the code fix, *because* an unhandled exception is far easier to detect and alert on in production than silent duplicate profiles — but insists both changes should ship together, not the index alone.
- **Poor Answer:** Recommends the index with no discussion of the coupled code change needed.

---

### D23. Why might `retraining_queue`'s lack of a terminal state (`"completed"`) eventually cause an operational incident, even though each individual write to it is correct?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Records transition `"pending" → "processing"` and then never move again — over a long enough time horizon, the collection accumulates an ever-growing set of permanently-`"processing"` documents. While this doesn't cause an immediate crash, it silently breaks the intended threshold logic (the next real batch of 100 corrections has to accumulate from zero, since stuck records no longer count as `"pending"`) and represents unbounded collection growth with no cleanup — eventually a genuine storage/performance concern, and a correctness concern for the retraining feature immediately.
- **Follow-ups:** "How would you detect this before it becomes a real incident?"
- **Common Mistakes:** Treating this purely as a data-hygiene issue rather than connecting it to the functional consequence (retraining threshold logic silently miscounting).
- **What This Tests:** Connecting a database-state observation to its actual product/feature impact, not just describing it as "messy data."
- **Red Flags:** Only mentions storage growth, missing the retraining-threshold-miscounting consequence.
- **Excellent Answer:** Proposes a simple monitoring query — count of `"processing"` documents older than some threshold (e.g., 1 hour) — as an early warning signal, since a healthy system with a real training-launch step implemented would expect this count to stay near zero.
- **Poor Answer:** Notes the collection "will grow forever" without connecting it to the specific functional bug it causes.

---

### D24. This system stores `merchant_profiles.confidence` as a field that's always `0.0`. Is that a database design flaw or an application-layer gap?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** Application-layer gap, not a database design flaw — the field exists correctly in the schema and the collection, but no code path anywhere ever sets it to anything other than its default. The database faithfully stores whatever the application writes; here, the application simply never writes a meaningful value.
- **Follow-ups:** "What would a meaningful value for this field represent, based on its name and context?"
- **Common Mistakes:** Blaming the database schema or MongoDB itself for a value never being set — a category error, since this is entirely an application-code responsibility.
- **What This Tests:** Correctly attributing a defect to the right layer of the stack.
- **Red Flags:** Suggests changing the database schema to "fix" what is purely a missing application-logic problem.
- **Excellent Answer:** Speculates plausibly that this field was likely intended to hold something like an aggregate confidence score derived from the merchant's categorization history, but no engine or service in the current codebase computes or writes such a value — it's a placeholder field for a feature that was never built.
- **Poor Answer:** Proposes a schema change instead of identifying the missing write path.

---

### D25. If you had to design the single most valuable new MongoDB index for this system today, considering both correctness and performance, what would it be and why?
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** A strong answer is a **unique** index on `merchant_profiles.canonical_name` — it simultaneously (a) fixes the single most-queried unindexed field in the system (every `/memory/*` request hits it), (b) closes the duplicate-profile race condition from a database-enforcement level rather than relying on perfect application logic, and (c) is a one-line, low-risk change with no query-pattern redesign required, unlike, say, adding sharding or read replicas.
- **Follow-ups:** "Defend this choice against someone who argues a compound index on `transactions` would deliver more value given it's the largest, fastest-growing collection."
- **Common Mistakes:** Picking the "biggest" or "most obviously slow" query without weighing the correctness bonus a unique index specifically provides beyond pure performance.
- **What This Tests:** Prioritization that accounts for more than one dimension of value (performance AND correctness AND blast radius/risk of the change itself) — the same senior-level judgment tested in Backend B25.
- **Red Flags:** Picks purely on "this collection is biggest" without weighing the correctness angle.
- **Excellent Answer:** Acknowledges the `transactions` argument as reasonable but counters that `transactions` growing large mainly affects analytics *latency*, a real but gracefully-degrading problem, whereas the `merchant_profiles` race condition is a silent *correctness* bug actively producing bad data today — correctness bugs compound (bad data poisons every downstream consumer) in a way pure latency problems don't.
- **Poor Answer:** Picks an index with no comparative reasoning against at least one credible alternative.
