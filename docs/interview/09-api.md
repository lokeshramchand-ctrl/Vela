# API — 15 Questions

---

### AP1. There are two handlers for `POST /v1/categorize`. Which one actually responds to a real request, and how do you know for certain?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** The one in `routers/v1.py`, mounted via `app.include_router(v1.router, ...)` at line 65 of `app.py`. The inline stub declared directly on `app` at line 73 is registered *after* the router, and Starlette matches routes in registration order — first match wins, so the router's handler always intercepts the request first. You know this for certain by reading `app.py` top to bottom and noting the exact line-order of `include_router` calls versus the inline `@app.post` decorator.
- **Follow-ups:** "What would you need to change in `app.py` to make the inline stub win instead?"
- **Common Mistakes:** Assuming FastAPI would raise a startup error for a duplicate path — it doesn't.
- **What This Tests:** Precise, source-verified understanding of route resolution order, not a guess.
- **Red Flags:** Can't cite the specific ordering that determines the outcome.
- **Excellent Answer:** Notes that simply moving the inline `@app.post("/v1/categorize", ...)` block to *before* the `include_router` calls would flip which handler wins — demonstrating genuine understanding of the mechanism, not just memorized trivia about this one case.
- **Poor Answer:** Guesses which handler wins without a verifiable mechanism.

---

### AP2. Why does `GET /memory/profile/{name}` return `404` for an unknown merchant while `GET /memory/state/{name}` returns `200` with a sentinel value for the identical underlying condition?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Two different, seemingly independent design choices for representing the same "not found" case: the full-profile endpoint treats it as an HTTP-level error condition; the lightweight state endpoint treats it as a normal, representable data value (`memory_state: "UNSEEN"`, a sentinel not present in the actual `MemoryState` enum). Nothing in the code suggests this was a deliberate, unified design decision — it reads as two endpoints built with different conventions.
- **Follow-ups:** "Which convention would you standardize on, and why?" "What would break for an existing client if you changed one to match the other?"
- **Common Mistakes:** Assuming both endpoints behave identically without checking each individually.
- **What This Tests:** Close reading of two adjacent, similar-looking endpoints for an unstated behavioral divergence.
- **Red Flags:** States both endpoints behave the same way.
- **Excellent Answer:** Argues for standardizing on the `404` convention as more RESTfully correct (an absent resource is conventionally a 404), but acknowledges that changing `/memory/state/{name}` to match would be a breaking change for any existing client that currently branches on the `"UNSEEN"` value rather than catching an HTTP error.
- **Poor Answer:** Picks a preferred convention with no discussion of migration/compatibility impact.

---

### AP3. Enumerate every distinct error-response shape this API produces, and explain why a generic client-side error handler can't be written once for the whole API.
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** At least three shapes exist: `{"detail": "..."}` (FastAPI's default `HTTPException` shape, used by most endpoints), `{"message": "..."}` (used by `routers/observability.py`'s manual `JSONResponse`), and `{"error": "..."}` (used by `rag/generator.py`'s degraded-response dicts, which aren't technically HTTP errors at all — they're `200` responses with an error-shaped payload nested inside `result`). A generic handler checking one specific key would silently miss errors shaped differently.
- **Follow-ups:** "Write the pseudocode for a client-side handler robust to all three shapes as they exist today."
- **Common Mistakes:** Missing that `rag/generator.py`'s "errors" aren't even HTTP-level errors — they're successful 200 responses containing an error-shaped value, a categorically different case from the other two.
- **What This Tests:** Whether the candidate distinguishes HTTP-transport-level errors from application-level "soft" error values embedded in a success response — an important, often-missed distinction.
- **Red Flags:** Treats all three as the same category of "error response."
- **Excellent Answer:** Explicitly separates the two categories (HTTP error status vs. `200` with an embedded error value) and notes a robust client needs *two* different handling paths: one for non-2xx status codes (checking multiple possible body keys), and one for inspecting successful RAG responses specifically for an `"error"` key inside `result`.
- **Poor Answer:** Lists the shapes without categorizing them correctly.

---

### AP4. Why does roughly half of this API's endpoints declare a `response_model` and half don't? What's the concrete, observable consequence?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** `routers/v1.py` and `routers/memory.py`'s endpoints declare typed `response_model`s (`CategorizeResponse`, `ResolutionResult`, `ConfidenceEvaluation`, `MerchantProfile`); every endpoint in `routers/analytics.py`, `routers/rag.py`, and `routers/observability.py` returns a plain dict/list with no declared response type. Consequence: the auto-generated OpenAPI schema (and therefore `/docs`, and any generated client SDK) is fully typed for the former group and generic/`any`-typed for the latter — and FastAPI performs no automatic response-shape validation for the untyped endpoints, so a bug that changes a returned field's type would be silently passed through rather than caught.
- **Follow-ups:** "Would you retrofit `response_model`s for every untyped endpoint, and in what order?"
- **Common Mistakes:** Assuming `response_model` is purely a documentation convenience with no runtime validation behavior — it's both.
- **What This Tests:** Understanding that `response_model` provides both documentation *and* a runtime correctness guarantee, and recognizing which endpoints currently lack that guarantee.
- **Red Flags:** Treats `response_model` as purely cosmetic/documentation-only.
- **Excellent Answer:** Prioritizes retrofitting `routers/analytics.py` first, since its endpoints have the most complex, multi-field response shapes (most likely to silently drift from documentation without a validation guardrail) compared to `routers/observability.py`'s trivially simple, unlikely-to-change stub responses.
- **Poor Answer:** Notes the inconsistency without proposing a prioritized fix.

---

### AP5. Why is there no API versioning strategy beyond a static `/v1` prefix, and what problem would arise the first time a genuinely breaking change is needed?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `/v1` is baked into route prefixes as a literal string with no accompanying deprecation mechanism, content-negotiation-based versioning, or `/v2` counterpart anywhere in the codebase — it's aspirational/placeholder naming rather than a functioning versioning system. The first genuinely breaking change (e.g., changing `ResolutionResult`'s shape) would either have to break every existing caller immediately, or require inventing a versioning strategy under time pressure rather than one already in place.
- **Follow-ups:** "Design a minimal versioning strategy you'd introduce today, before it's urgently needed."
- **Common Mistakes:** Assuming `/v1` in the URL constitutes a real versioning strategy just because the string exists.
- **What This Tests:** Recognizing that a version *label* isn't the same as a version *strategy* (which requires a plan for what happens at v2).
- **Red Flags:** Says "it's already versioned, see the `/v1` prefix" with no critique.
- **Excellent Answer:** Proposes introducing a `/v2` prefix pattern now, even before it's needed, alongside a lightweight deprecation-header convention (`Deprecation`/`Sunset` HTTP headers on `/v1` responses once `/v2` exists) — establishing the pattern while there's no time pressure, rather than improvising one during an urgent breaking change.
- **Poor Answer:** No concrete versioning proposal.

---

### AP6. Why does `resolution_method` in `ResolutionResult`'s docstring describe a possible value (`"rule_engine"`) that the resolver never actually produces?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** `services/merchant_resolver.py::resolve` only ever returns `"exact_alias"`, `"substring"`, or `"none"` — `"rule_engine"` appears nowhere in its actual logic. This is documentation drift: the docstring likely describes an intended or previously-planned value (perhaps referencing `engines/rule_engine.py`, a wholly separate system) that was never wired into this specific function, or was removed without updating the docstring.
- **Follow-ups:** "How would you verify a docstring's claimed values are exhaustive and accurate for any function?"
- **Common Mistakes:** Assuming a docstring's description of possible values is authoritative without checking the actual return statements.
- **What This Tests:** Habitual skepticism toward documentation as a description of *intent* rather than *verified current behavior* — a recurring theme this whole interview bank tests in different forms.
- **Red Flags:** Trusts the docstring's claim without checking `resolve()`'s actual code.
- **Excellent Answer:** Proposes the verification method generically: grep the function body for every `return`/`resolution_method=` literal and confirm the set matches the docstring exactly — a five-minute check that would have caught this specific drift.
- **Poor Answer:** Correctly identifies the mismatch but has no general verification habit to propose.

---

### AP7. Why does `POST /v1/analytics/anomaly/check` violate REST conventions, and does it actually matter functionally?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** It's a `POST` that reads its inputs from query parameters rather than a JSON request body — every other `POST` endpoint in this API uses a body. It doesn't break functionality (FastAPI supports query parameters on any method), but it breaks the *predictability* of the API's conventions for any client or generated SDK that assumes "POST = body" uniformly across this specific API.
- **Follow-ups:** "Would you consider this a `GET` instead, given it has no side effects?"
- **Common Mistakes:** Overstating this as a functional bug rather than a consistency/convention issue.
- **What This Tests:** Correctly scoping a real but minor issue without inflating its severity.
- **Red Flags:** Claims this causes an actual functional failure.
- **Excellent Answer:** Notes that since this endpoint has zero side effects (pure read against `behavior_patterns`), it arguably *should* be a `GET` with query parameters (which would then be conventionally correct), rather than fixing it by moving the same parameters into a `POST` body — a cleaner fix than just "conform to the POST-body convention."
- **Poor Answer:** Proposes only "move params to a JSON body" without questioning whether `POST` is even the right verb here.

---

### AP8. Trace exactly what a client sees, end-to-end, when calling `POST /v1/feedback/` against the actual running application today.
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** A generic Starlette `404 Not Found`, because `feedback/api_router.py`'s router is never included via `app.include_router(...)` in `app.py` — the path simply doesn't exist in the live route table, distinct from a `404` returned *by* a matched handler for a legitimate "not found" business case (like `GET /memory/profile/{name}` for an unknown merchant). A client (or a developer debugging this) would see identical HTTP status codes for two entirely different underlying causes: "this resource doesn't exist" vs. "this endpoint was never wired up at all."
- **Follow-ups:** "How would you distinguish these two categories of 404 as an API consumer debugging a failing integration?"
- **Common Mistakes:** Assuming the router's well-written code means the endpoint is reachable — code correctness and route registration are two independent conditions that both need to hold.
- **What This Tests:** Distinguishing "a 404 the application's business logic intentionally produced" from "a 404 because the routing table has no matching entry at all" — a subtle but important operational distinction.
- **Red Flags:** Assumes the endpoint works because the handler code looks correct.
- **Excellent Answer:** Proposes checking `/docs` (the auto-generated OpenAPI page) as the fastest way to distinguish the two cases — an unmounted router's paths simply won't appear there at all, whereas a "real" business-logic 404 would show its endpoint documented with a `404` response documented as a possible outcome.
- **Poor Answer:** Correctly predicts the 404 but doesn't distinguish it from a "normal" business 404.

---

### AP9. Why might treating `/v1/observability/drift/analyze`'s `"status": "success"` response as meaningful be dangerous for anyone building automation on top of this API?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** The endpoint is a pure stub that always returns this exact response regardless of any actual analysis happening (none does) — an automated system (e.g., a scheduled job that "triggers drift analysis, then alerts if issues found") built on top of this endpoint would perpetually see success with no real signal behind it, creating false confidence that drift monitoring is functioning when it categorically isn't.
- **Follow-ups:** "How would you design this endpoint's contract to make its 'stub-ness' impossible to miss for an API consumer?"
- **Common Mistakes:** Treating this purely as an internal code-quality issue rather than connecting it to the real external consequence for anyone building on top of this specific contract.
- **What This Tests:** Thinking about API contracts from the consumer's trust perspective, not just the implementer's.
- **Red Flags:** Doesn't connect the stub status to a concrete automation-risk scenario.
- **Excellent Answer:** Proposes that until real drift analysis exists, the endpoint should honestly return something like `501 Not Implemented` or a response body explicitly stating `"stub": true`, rather than a `200`/`"success"` response indistinguishable from genuine functionality — prioritizing honest failure over false success.
- **Poor Answer:** Notes the risk without proposing a concrete contract change.

---

### AP10. Why does this API expose `/metrics` and `/health` with no auth while everything else requires a key — is this inconsistency, or intentional design?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Intentional, and a common, defensible pattern — these two endpoints exist for infrastructure tooling (load balancers, orchestrators, Prometheus scrapers) that typically shouldn't need to carry application-level credentials, and both are attached directly on `app` outside of any `include_router(dependencies=[...])` call, distinguishing them structurally (not accidentally) from the five routers that do require auth.
- **Follow-ups:** "How would you verify this was intentional rather than an oversight, just from reading the code?"
- **Common Mistakes:** Assuming any unauthenticated endpoint must be an oversight without considering the legitimate operational reason two specific endpoints might deliberately be exempted.
- **What This Tests:** Distinguishing a deliberate, structurally-consistent exception from a genuine oversight — verified by checking *how* the exemption is implemented, not just that it exists.
- **Red Flags:** Assumes this must be a bug without examining the structural evidence for intent.
- **Excellent Answer:** Notes the structural tell: both exempted endpoints are registered *outside* the `include_router` pattern that every authenticated endpoint uses — if this were an oversight, you'd more likely see an authenticated router with one route accidentally missing its dependency, not two entirely separately-registered, conventionally-unauthenticated endpoints (health/metrics) matching a well-known industry pattern.
- **Poor Answer:** Correct conclusion (intentional) with no supporting evidence from the code's structure.

---

### AP11. What does the fact that `GET /v1/analytics/patterns/merchants` has no time-window parameter, while `GET /v1/analytics/patterns/categories` does, tell you about how these two endpoints were likely developed?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** Most plausibly, they were developed somewhat independently without a shared design review pass, since both answer conceptually similar "top X" spend questions but diverge in an API-surface detail (a `days` parameter) that would have been natural to apply consistently if designed together. Without direct evidence of the actual development history, this is an inference from the API's current shape, not a certainty.
- **Follow-ups:** "How would you verify this hypothesis, if you had access to the git history?"
- **Common Mistakes:** Stating this inference as a certain fact rather than a reasonable but unverified hypothesis.
- **What This Tests:** Appropriately hedged reasoning about process/history inferred from code artifacts alone.
- **Red Flags:** States the development history as established fact with no hedging.
- **Excellent Answer:** Proposes checking `git blame`/`git log` on both specific functions to see if they were added in the same commit/PR (suggesting a shared design pass that simply missed the inconsistency) or different ones entirely (suggesting genuinely independent development) — grounding the hypothesis in a concrete, checkable method rather than pure speculation.
- **Poor Answer:** Offers the hypothesis with no proposed way to verify it.

---

### AP12. If you were asked to add pagination to `GET /v1/analytics/patterns/categories`, what specific code and API-contract changes would you make?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Add `$skip`/`$limit` stages to `analytics/spending_patterns.py::get_category_breakdown`'s aggregation pipeline, and add corresponding `page`/`page_size` (or `offset`/`limit`) query parameters to the router handler, with sensible defaults preserving current behavior for existing callers who don't specify them. The response might also need to change from a bare array to an object with pagination metadata (`{"items": [...], "total": N, "page": P}`) — a breaking change for anyone currently expecting a bare array, worth flagging explicitly.
- **Follow-ups:** "Is this endpoint actually a strong candidate for pagination, given the likely small number of distinct categories in practice?"
- **Common Mistakes:** Proposing the pagination mechanics without acknowledging the response-shape change would break existing callers expecting a bare array.
- **What This Tests:** Whether the candidate thinks through backward compatibility even for a seemingly simple, additive-sounding feature request.
- **Red Flags:** Doesn't mention the response-shape breaking-change implication at all.
- **Excellent Answer:** Correctly questions the premise — given `TransactionCategory` has only 8 members, this specific endpoint is a poor candidate for pagination (the result set is inherently small and bounded); a more valuable target for the same pagination pattern would be `GET /v1/analytics/patterns/merchants`, whose result set can grow unboundedly with the number of distinct merchants a user has transacted with.
- **Poor Answer:** Implements the requested feature literally without questioning whether it's the right endpoint to prioritize.

---

### AP13. Why can't a client reliably distinguish "Milvus is down" from "no semantic matches were found" when calling `POST /v1/explain`?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `milvus/search_vectors.py::find_similar_behaviors` catches every exception broadly and returns `[]` either way, and `rag/retriever.py`/`rag/generator.py` propagate that ambiguity forward — both scenarios ultimately produce the identical client-visible response: `{"retrieved_documents": 0, "result": {"error": "No historical behavior found to explain this transaction."}}`. There's no distinct error code, header, or field anywhere in the response indicating which underlying cause occurred.
- **Follow-ups:** "Would you fix this at the API-contract level, and if so, how?"
- **Common Mistakes:** Assuming this is purely an internal logging concern with no client-facing consequence — it directly limits what any client-side error-handling or monitoring logic can distinguish.
- **What This Tests:** Connecting an internal implementation choice (broad exception handling) to its concrete external API-contract consequence.
- **Red Flags:** Treats this purely as a server-side logging gap with no client-visible impact.
- **Excellent Answer:** Proposes distinguishing the two cases at the API level with a different `result` shape or an explicit `degraded: true` flag for genuine infrastructure failures versus a clean, expected "no data available" response for legitimate empty results — giving API consumers the information to decide whether to retry (infrastructure failure) or not (genuinely no data).
- **Poor Answer:** Identifies the ambiguity without proposing any API-contract-level fix.

---

### AP14. Design the ideal error-response contract for this API, given everything discussed about its current inconsistencies.
- **Difficulty:** Expert | **Importance:** 7
- **Expected Answer:** A single, consistent envelope for every non-2xx response across every router, e.g., `{"error": {"code": "INVALID_API_KEY", "message": "...", "details": {...}}}`, implemented via one or a small number of global exception handlers (`app.add_exception_handler(...)`) registered for `HTTPException`, `RequestValidationError`, and a base application exception class — retiring the current per-handler ad hoc shapes (`{"detail": ...}`, `{"message": ...}`, `{"error": ...}`) in favor of this one contract.
- **Follow-ups:** "How would you roll this out without breaking every existing integration simultaneously?"
- **Common Mistakes:** Proposing a good target shape without addressing migration — a real API redesign question always needs a rollout plan, not just an end-state description.
- **What This Tests:** Whether the candidate designs for the *transition*, not just the destination — genuinely important for anyone who has to ship changes to a live API.
- **Red Flags:** Only describes the ideal end state with no rollout consideration.
- **Excellent Answer:** Proposes an additive rollout: introduce the new envelope alongside the old fields temporarily (e.g., both `{"detail": "...", "error": {"code": ..., "message": "..."}}`) for one deprecation cycle, giving existing clients time to migrate before the legacy fields are removed — the standard safe pattern for evolving a live API contract.
- **Poor Answer:** Proposes an immediate, breaking cutover with no transition period.

---

### AP15. If you had to pick the single API design change that would most improve this system's usability for external developers, what would it be?
- **Difficulty:** Expert | **Importance:** 7
- **Expected Answer:** A strong, defensible answer is consistent response envelopes and universal `response_model` declarations (AP3/AP4 combined) — this single class of change would fix the OpenAPI-schema accuracy, enable reliable typed client generation, and eliminate the need for consumers to special-case error handling per endpoint, all from one coordinated effort, unlike fixing individual endpoint quirks (AP7, AP2) one at a time.
- **Follow-ups:** "Defend this against someone who argues fixing the broken `/v1/categorize` endpoint is more urgent for usability."
- **Common Mistakes:** Naming a single functional bug fix (important, but narrow) rather than a systemic consistency fix that compounds in value across every current and future endpoint.
- **What This Tests:** The same breadth-of-impact prioritization tested in Performance P1 and Backend B25, applied specifically to API design — consistency across this whole interview bank in how the candidate reasons about "biggest impact" questions.
- **Red Flags:** Names a single bug fix without engaging with why a systemic consistency fix might have broader value.
- **Excellent Answer:** Explicitly acknowledges the counter-argument (a broken endpoint is a hard blocker, a design inconsistency is a friction cost) and reasons that both matter, but frames them as different *kinds* of priority: fix `/v1/categorize` first because it's a correctness blocker with a small, contained fix, then invest in the systemic consistency work because it compounds in value for every subsequent endpoint and integration going forward.
- **Poor Answer:** Picks one without acknowledging the other has a legitimate, different kind of urgency.
