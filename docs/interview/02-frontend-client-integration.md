# Frontend / Client Integration â€” 8 Questions

> This repository has **no frontend code** â€” no HTML, JavaScript, templates, or UI framework of any kind exist anywhere in it. These questions instead test whether a candidate can reason about what Vela's actual API contract, authentication model, and response inconsistencies mean for *any* real client that would have to consume it â€” a legitimate and important system-design skill, without inventing frontend code that doesn't exist.

---

### F1. Given there's no CORS middleware anywhere in `app.py`, what kind of client can safely call this API?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Server-to-server callers (another backend, a script, a mobile app making direct HTTPS calls) â€” none of these are subject to browser CORS enforcement. A browser-based single-page app calling this API directly from JavaScript would fail preflight `OPTIONS` checks, since no `Access-Control-Allow-Origin` header is ever sent.
- **Follow-ups:** "How would you add CORS support without opening this up to any origin?"
- **Common Mistakes:** Assuming CORS is a security feature the *server* needs for protection â€” it's actually a browser-enforced restriction that protects *users*, and its absence only matters for browser clients specifically.
- **What This Tests:** Correct mental model of what CORS actually protects against and who enforces it.
- **Red Flags:** Says "CORS is missing so the API is insecure" â€” conflates CORS with authentication/authorization.
- **Excellent Answer:** Notes that `fastapi.middleware.cors.CORSMiddleware` with an explicit allow-list (not `allow_origins=["*"]`, especially given credentials are sent via a header) would be the correct fix if a browser client is ever needed.
- **Poor Answer:** Vague "add CORS headers" with no mention of origin allow-listing or credentials implications.

---

### F2. If you were told to build a web frontend against this API today, what's the first architectural problem you'd raise with the backend team?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** The authentication model â€” a single static shared API key (`X-Vela-API-Key: Vela_test_key_123`) is fundamentally incompatible with a browser client, since any key embedded in client-side code is visible to anyone via dev tools or the network tab. A real frontend would need the backend to add a proper session/token-based auth flow (e.g., login â†’ short-lived JWT) before it could be built safely.
- **Follow-ups:** "What would a minimal safe architecture look like â€” does the frontend ever see the real API key?"
- **Common Mistakes:** Proposing to "just call the API directly from the frontend with the key hardcoded" as if that's an acceptable stopgap.
- **What This Tests:** Security-conscious system design thinking, applied to a concrete integration scenario.
- **Red Flags:** No mention of the key-exposure problem at all; treats the API as ready for browser integration as-is.
- **Excellent Answer:** Proposes a backend-for-frontend (BFF) pattern â€” the browser talks to a thin server-side layer that holds the real API key and never exposes it to the client â€” as the pragmatic fix without waiting for Vela's own auth model to be redesigned.
- **Poor Answer:** "Just use HTTPS, that's secure enough" â€” misunderstands that HTTPS protects data in transit, not a key visible in the client's own JavaScript bundle.

---

### F3. Half of Vela's endpoints declare a `response_model` and half don't. What does this mean for generating a typed client SDK?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Tools that generate typed clients from OpenAPI specs (e.g., `openapi-typescript`, `orval`) rely on accurate `response_model` declarations to produce typed response shapes. For the untyped endpoints (`routers/analytics.py`, `routers/rag.py`, `routers/observability.py`), the generated client would fall back to `any`/`unknown` types, losing compile-time safety for roughly half the API surface.
- **Follow-ups:** "How would you retrofit `response_model`s without breaking existing consumers?"
- **Common Mistakes:** Assuming FastAPI's OpenAPI schema is always fully accurate regardless of whether `response_model` is declared.
- **What This Tests:** Practical understanding of how OpenAPI-driven tooling depends on backend-declared contracts.
- **Red Flags:** Doesn't know what a `response_model` even affects in terms of generated documentation/clients.
- **Excellent Answer:** Notes this could be done incrementally, endpoint by endpoint, and that adding a `response_model` to an endpoint that previously returned an untyped dict is a backward-compatible change as long as the model's fields are a superset of what's actually returned.
- **Poor Answer:** "The client would just work the same either way" â€” incorrect; type generation is materially degraded.

---

### F4. `GET /memory/profile/{name}` returns `404` for an unknown merchant, but `GET /memory/state/{name}` returns `200` with a sentinel value for the same underlying condition. How should a frontend handle this?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** The frontend needs two different handling paths for what is conceptually the same "not found" condition â€” catching an HTTP error for one endpoint, and checking a data field (`memory_state === "UNSEEN"`) for the other. This is real API design debt that pushes complexity onto every consumer.
- **Follow-ups:** "If you owned both the frontend and backend, would you push for a fix, and what would it look like?"
- **Common Mistakes:** Not noticing the inconsistency exists until explicitly comparing the two endpoints' behavior.
- **What This Tests:** Attention to API contract detail â€” the kind of thing that causes real, hard-to-debug frontend bugs ("why does my error boundary not catch this one").
- **Red Flags:** Assumes both endpoints behave the same way without checking.
- **Excellent Answer:** Notes this is exactly the kind of inconsistency that should be caught by an API contract test, not discovered by a frontend engineer debugging in production.
- **Poor Answer:** "Just handle whatever the API returns" with no recognition of the added client-side complexity.

---

### F5. Error responses across this API use at least three different shapes (`{"detail": ...}`, `{"message": ...}`, `{"error": ...}`). How would this affect a frontend's error-handling code?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** A generic error-handling utility (e.g., "show `error.message` in a toast") can't be written once and reused across all endpoints â€” it would need per-endpoint or defensive multi-key lookup logic (`data.detail ?? data.message ?? data.error`), which is fragile and easy to get wrong for a new endpoint.
- **Follow-ups:** "What would you propose as a standard error envelope, and how would you migrate to it?"
- **Common Mistakes:** Assuming FastAPI enforces one consistent error shape automatically â€” it doesn't; every handler is free to shape its own response.
- **What This Tests:** Understanding that API consistency is a deliberate design responsibility, not something a framework guarantees for free.
- **Red Flags:** Says "just parse `response.json().message`" without acknowledging it will break on endpoints using a different key.
- **Excellent Answer:** Proposes a single global exception handler (there is currently only one, for rate limiting) that normalizes every error response to one shape, and migrating existing ad hoc responses toward it.
- **Poor Answer:** No proposed fix, just describes the inconsistency.

---

### F6. Why might a frontend team be surprised that `/v1/analytics/*` endpoints all return the same data regardless of which user's session is calling them?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** `routers/analytics.py` hardcodes `TEST_USER = "user_123"` for every request â€” there's no per-caller data scoping at all today. A frontend built to show "my spending" would actually be showing the same fixed test user's data to every logged-in user, a serious functional and privacy bug if ever deployed with real users.
- **Follow-ups:** "What backend change is a prerequisite before a real multi-user frontend could be built against this?"
- **Common Mistakes:** Assuming the API key somehow identifies which user's data to return â€” it doesn't; `validate_api_key`'s returned identity is discarded and never used.
- **What This Tests:** Whether the candidate connects an authentication gap directly to a concrete, user-facing consequence.
- **Red Flags:** Assumes multi-tenancy already works because "there's an API key."
- **Excellent Answer:** Explicitly traces the chain: `core/security.py` doesn't resolve real identity â†’ `routers/analytics.py` has no real user_id to use â†’ hardcodes one â†’ every "personalized" view is identical for every caller.
- **Poor Answer:** Doesn't connect the dots between auth and per-user data scoping at all.

---

### F7. The OpenAPI docs at `/docs` are auto-generated. What's misleading about them for a frontend developer who trusts them at face value?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** They'll show a duplicate `/v1/categorize` operation (one from the router, one from the dead inline stub in `app.py`) without indicating that only one is actually reachable; they'll show generic/untyped response schemas for every `routers/analytics.py`/`routers/rag.py`/`routers/observability.py` endpoint; and nothing in the docs indicates that `/v1/categorize` currently throws a 500 on every call, or that `/v1/feedback/` (if visible at all, which it isn't, since it's never mounted) doesn't actually exist in the live route table.
- **Follow-ups:** "How would a frontend team discover these gaps before writing broken integration code?"
- **Common Mistakes:** Treating auto-generated docs as an infallible source of truth about runtime behavior.
- **What This Tests:** Healthy skepticism about auto-generated documentation vs. actual verified behavior.
- **Red Flags:** Says the docs are "always accurate since FastAPI generates them automatically."
- **Excellent Answer:** Recommends a contract test suite that hits every documented endpoint and asserts real behavior, specifically to catch drift between what `/docs` implies and what actually happens.
- **Poor Answer:** No skepticism about auto-generated docs at all.

---

### F8. If this API were to gain a real frontend, what response-shape and versioning decisions made today would make that migration harder than it needs to be?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** No API versioning strategy beyond a static `/v1` prefix with no deprecation mechanism; inconsistent response envelopes (bare arrays vs. bare objects vs. objects with nested `details`/`result` keys); and the two-shape "not found" handling in the memory router. Any frontend built today would be tightly coupled to these specific inconsistencies, making a later cleanup a breaking change for that frontend rather than an internal refactor.
- **Follow-ups:** "Would you fix these before or after building the first frontend integration, and why?"
- **Common Mistakes:** Treating versioning and response-shape consistency as "nice to have" polish rather than a real cost multiplier for every future consumer.
- **What This Tests:** Long-horizon thinking about API design debt compounding as more clients are added.
- **Red Flags:** No mention of versioning strategy at all when asked directly about migration difficulty.
- **Excellent Answer:** Argues for fixing response-shape consistency *before* the first real frontend is built, since retrofitting it after a client depends on the current shapes turns an internal cleanup into a coordinated breaking-change rollout.
- **Poor Answer:** "It'll be fine, we'll just update the frontend when the API changes" â€” underestimates the coordination cost once external consumers exist.

