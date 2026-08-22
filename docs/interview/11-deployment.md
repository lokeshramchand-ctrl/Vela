# Deployment â€” 12 Questions

---

### DP1. What happens if you run `docker build` on this repository's `Dockerfile` right now, and why?
- **Difficulty:** Medium | **Importance:** 9
- **Expected Answer:** The build itself likely succeeds (installing `requirements.txt` doesn't fail on its own), but the resulting image fails immediately on `CMD ["uvicorn", "app:app", ...]` with `ModuleNotFoundError: No module named 'fastapi'` â€” because `requirements.txt` lists OS-level/`apt`-adjacent packages (`Automat`, `Twisted`, `PyGObject`, `python-apt`, etc.), not this application's actual runtime dependencies (`fastapi`, `motor`, `pymilvus`, and others). The container builds successfully but cannot run the application it's supposed to serve.
- **Follow-ups:** "How would you have discovered this without actually running the build?"
- **Common Mistakes:** Assuming a successful `docker build` implies the resulting container will actually run correctly.
- **What This Tests:** Distinguishing "the build step succeeded" from "the application works" â€” a distinction many candidates conflate.
- **Red Flags:** Says the build would fail â€” it wouldn't; the *runtime* fails, at container start, not at build time.
- **Excellent Answer:** Notes this could be discovered without running anything: cross-referencing every `import` statement across the codebase against `requirements.txt`'s contents shows zero overlap with the actual application dependencies, only environment/OS packages â€” a static, five-minute code review check.
- **Poor Answer:** Correctly predicts failure but attributes it to the wrong stage (build vs. runtime).

---

### DP2. Why does `docker-compose_production.yaml` fail to produce a working deployment even if the image itself were fixed?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** Its `environment:` block sets `MONGO_URI`, `MONGO_DB_NAME`, `MILVUS_HOST`, `MILVUS_PORT` â€” none of which match `core/config.py::Settings`' actual required field names (`MONGODB_URI`, `MONGODB_DB_NAME`, `MILVUS_URI`), and it doesn't set `OLLAMA_URI`/`OLLAMA_HOSTS`, `EMBED_MODEL`, `LLM_MODEL`, or `Vela_API_KEY` at all â€” all of which `Settings()` requires with no default. The application would fail Pydantic settings validation and crash immediately at import time, before ever reaching a request.
- **Follow-ups:** "How would you catch this mismatch in CI before it ever reaches a real deployment attempt?"
- **Common Mistakes:** Assuming the compose file's environment variables are correctly wired just because they have plausible-sounding names.
- **What This Tests:** Cross-referencing a deployment config against the application's actual configuration schema, rather than assuming they're in sync.
- **Red Flags:** Doesn't check the actual variable names required by `core/config.py`.
- **Excellent Answer:** Proposes a CI smoke test that runs `python -c "from core.config import settings"` (or equivalent) against each compose file's declared environment, which would fail loudly and immediately catch this exact mismatch before any real deployment attempt.
- **Poor Answer:** Correctly identifies mismatched names in isolation without connecting it to the concrete startup-crash consequence or proposing prevention.

---

### DP3. What's the actual, concrete risk of the credential committed in `docker-compose_production.yaml`, beyond "secrets shouldn't be in git"?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Anyone with read access to the repository (current collaborators, and anyone who ever clones it, including via any historical access even after the file is later modified â€” git history retains it) has the full MongoDB username and password for whatever instance it points to. Even if that instance's connectivity is later restricted or the credential rotated, the practice reveals a deployment process that doesn't route secrets through environment injection or a secrets manager at commit time â€” a systemic gap, not just a one-off mistake.
- **Follow-ups:** "What's your recommended remediation sequence, in order?"
- **Common Mistakes:** Treating the fix as "delete the line" rather than recognizing the credential must be treated as permanently compromised.
- **What This Tests:** Practical incident-response thinking for a leaked-secret scenario, applied to a deployment-config context.
- **Red Flags:** Proposes only removing the line from the file without addressing rotation or git history.
- **Excellent Answer:** Sequences the fix: (1) rotate the MongoDB credential immediately, treating the old one as burned; (2) remove the line from the current file and replace it with an environment-variable reference or secrets-manager lookup; (3) separately evaluate whether git history needs surgical cleanup, weighing that disruption against the already-completed rotation making it lower priority.
- **Poor Answer:** Single-step fix with no sequencing or prioritization.

---

### DP4. Why does `README.md`'s described local-development compose setup diverge from the actually-committed `docker-compose_local.yaml`?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** The README's setup instructions describe a compose file that includes a `milvus-standalone` service; the actually-committed `docker-compose_local.yaml` only defines `mongodb` and `Vela-backend` â€” no Milvus service at all. Someone following the README literally would author a different file than what's checked into source control, or would need to notice the discrepancy and author their own Milvus service to get the full feature set working locally.
- **Follow-ups:** "How would you prevent documentation and infrastructure-as-code from drifting apart like this in the future?"
- **Common Mistakes:** Assuming documentation accurately reflects the current state of checked-in infrastructure files without verifying them side by side.
- **What This Tests:** The habit of cross-checking documentation against actual committed artifacts â€” documentation drift is a common, real-world source of onboarding friction.
- **Red Flags:** Assumes README instructions must match the committed files without checking.
- **Excellent Answer:** Proposes a lightweight CI check (or even just a pre-commit hook) that fails if `docker-compose_local.yaml` is modified without a corresponding README update in the same commit, or vice versa â€” a low-effort guardrail against exactly this kind of drift recurring.
- **Poor Answer:** Notes the discrepancy exists without proposing any prevention mechanism.

---

### DP5. This `Dockerfile` has no `HEALTHCHECK` directive. What's the practical consequence for an orchestrator like Docker Swarm or a bare `docker run` deployment?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Without a `HEALTHCHECK`, Docker (and orchestrators relying on Docker's own health status) has no way to know whether the container is actually serving traffic correctly versus merely "running" (the process hasn't crashed) â€” a container could be up but stuck (e.g., failed database connections leaving it in a degraded state per `/health`'s own reporting) with no automatic detection or restart triggered by the container runtime itself.
- **Follow-ups:** "Would adding `HEALTHCHECK CMD curl -f http://localhost:8000/health` be sufficient, given what `/health` actually reports?"
- **Common Mistakes:** Assuming "the container is running" is equivalent to "the application is healthy."
- **What This Tests:** Understanding the distinction between process-level liveness (which Docker tracks by default) and application-level health (which requires explicit configuration).
- **Red Flags:** Conflates "container running" with "application healthy."
- **Excellent Answer:** Notes a naive `HEALTHCHECK` hitting `/health` would be insufficient on its own, since `/health` always returns `200` even when reporting `"degraded"` (per its own documented design) â€” a proper healthcheck script would need to also inspect the response body's `status` field, not just the HTTP status code, to correctly distinguish healthy from degraded.
- **Poor Answer:** Proposes adding a `HEALTHCHECK` without accounting for `/health`'s always-200 behavior.

---

### DP6. Why does running this application with a single Uvicorn worker and no process manager (like Gunicorn or a supervisor) matter for deployment resilience specifically, beyond the concurrency concerns discussed elsewhere?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** If the single worker process crashes (an unhandled exception escaping all the way up, an out-of-memory condition, etc.), there's nothing at the process level to automatically restart it â€” the container itself would exit, and recovery depends entirely on the container orchestrator's restart policy (`restart: always`, present in both compose files) rather than any in-application resilience. This works, but means every crash incurs the full container restart cost (including the multi-second Milvus/Mongo reconnection sequence discussed in the Architecture category) rather than a lighter-weight process-level respawn.
- **Follow-ups:** "What would a Gunicorn-managed multi-worker setup change about crash recovery specifically?"
- **Common Mistakes:** Conflating "no process manager" with "no recovery mechanism at all" â€” the compose files' `restart: always` does provide a recovery path, just a coarser-grained one.
- **What This Tests:** Correctly identifying which layer (container orchestration vs. process management) is actually providing the resilience that exists, and which layer is absent.
- **Red Flags:** Claims there's no recovery mechanism at all, missing the container-level `restart: always`.
- **Excellent Answer:** Notes a Gunicorn-managed setup with multiple worker processes would let one worker crash and restart independently, without a total connection-re-establishment cost or a brief window of zero availability â€” versus the current single-process-per-container model where a crash means the *entire* container (and therefore all capacity) briefly goes to zero before the orchestrator restarts it.
- **Poor Answer:** Doesn't distinguish container-level from process-level recovery mechanisms.

---

### DP7. Why is `.dockerignore` not excluding `.env`, and why does that matter given the current `docker-compose_production.yaml` doesn't use an `env_file` directive?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `.dockerignore` currently excludes `.venv`, `__pycache__/`, `*.log`, `.git`, `.gitignore` â€” but not `.env`. Today this doesn't cause active harm, since `docker-compose_production.yaml` passes secrets via an inline `environment:` block rather than an `env_file:` directive, meaning no `.env` file needs to exist in the build context for production. But if a developer ever switched to `env_file:` (as `docker-compose_local.yaml` already does) without also fixing `.dockerignore`, and a `.env` file happened to exist in the build context at that time, `COPY . .` in the `Dockerfile` would bake its contents directly into an image layer â€” a real secret-leakage risk into a container image that might be pushed to a registry.
- **Follow-ups:** "Should `.dockerignore` exclude `.env` regardless of current usage patterns, as a defensive measure?"
- **Common Mistakes:** Declaring this an active vulnerability today without checking whether the current production compose file's actual secret-delivery mechanism (`environment:` block, not `env_file`) makes it currently moot.
- **What This Tests:** Precise reasoning about a *latent* risk that depends on a specific, checkable precondition (how secrets are currently delivered) rather than an active one.
- **Red Flags:** Declares this an active, currently-exploited leak without checking the actual current secret-delivery mechanism.
- **Excellent Answer:** Recommends adding `.env` to `.dockerignore` regardless of current usage, purely as defense in depth against a future, easy-to-make mistake (someone switching to `env_file:` without remembering this specific interaction) â€” a cheap, permanent fix for a currently-latent but easily-triggered risk.
- **Poor Answer:** Either dismisses this entirely as irrelevant, or overstates it as an active current leak.

---

### DP8. What would you need to verify before approving this application for its first production deployment, given everything discussed in this interview so far?
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** At minimum: (1) `POST /v1/categorize` is fixed (a core advertised feature currently 500s on every call); (2) `requirements.txt` reflects real dependencies (the container must actually be able to run); (3) `core/security.py` reads the real `Vela_API_KEY` setting, not a hardcoded literal; (4) the committed credential in `docker-compose_production.yaml` is rotated and removed; (5) `docker-compose_production.yaml`'s environment variable names match `core/config.py`'s actual requirements; (6) at least the highest-value MongoDB indexes exist, given production data volume will only grow from day one. This list should be treated as a hard gate, not a "nice to have before v2" backlog.
- **Follow-ups:** "Which of these would you consider truly blocking versus merely strongly recommended?"
- **Common Mistakes:** Producing an incomplete list that misses one of the launch-blocking items already established elsewhere in this interview (e.g., forgetting the compose env-var mismatch, which would prevent the app from even starting).
- **What This Tests:** Synthesis across the entire interview â€” the ability to compile a coherent, prioritized go/no-go checklist from everything previously discussed, the actual deliverable a senior engineer would produce for a real launch readiness review.
- **Red Flags:** Produces a short, incomplete list, or treats every item as equally optional.
- **Excellent Answer:** Explicitly separates hard blockers (1, 2, 3, 4, 5 â€” each of which either prevents startup entirely or represents an unacceptable security exposure) from strongly-recommended-but-technically-non-blocking items (6 â€” a correctness/performance concern that degrades gracefully rather than causing a hard failure), giving a decision-maker a clear go/no-go versus "should schedule soon" distinction.
- **Poor Answer:** Lists items with no distinction between hard blockers and softer recommendations.

---

### DP9. Why might a blue-green or rolling deployment strategy be harder to implement safely for this application than it would first appear?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Because `core/ollama_client.py`'s host resolution and Milvus's collection-creation logic both run at import/startup time with real side effects (network calls, possible schema creation) â€” a rolling deployment bringing up new instances alongside old ones means multiple processes independently performing these startup sequences concurrently, which is probably safe for read-only host resolution but is a genuine question mark for Milvus's `_ensure_collections()` (a `has_collection` check followed by a `create_collection` call, with a theoretical race if two fresh instances start at exactly the same moment against a not-yet-existing collection).
- **Follow-ups:** "How would you verify whether this race is actually possible, or whether Milvus itself guards against it?"
- **Common Mistakes:** Assuming rolling deployments are always straightforward for stateless-looking web services without considering side effects hidden in import-time code.
- **What This Tests:** Recognizing that "the app looks stateless at the request level" doesn't mean its *startup* sequence is free of side effects that could interact badly under concurrent multi-instance startup.
- **Red Flags:** Assumes rolling deployment is trivially safe without considering the import-time collection-creation logic at all.
- **Excellent Answer:** Proposes verifying this specific race by checking whether Milvus's `create_collection` call is itself idempotent/safe under a "does this collection already exist" race (many databases handle "create if not exists" races gracefully server-side) â€” a concrete verification step rather than either dismissing or catastrophizing the risk without checking.
- **Poor Answer:** Identifies the theoretical concern without proposing any way to actually verify its real severity.

---

### DP10. Why does this codebase's total absence of a CI pipeline matter more for deployment safety than it might for a smaller personal project?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Every one of the concrete, verified defects discussed throughout this interview (the broken `/v1/categorize` handler, the `requirements.txt` mismatch, the `Optional` import bug, the compose env-var mismatch) is exactly the kind of thing a basic CI pipeline â€” even just "install dependencies and run `pytest`" â€” would have caught automatically, immediately, on every commit, rather than requiring an extensive manual documentation/review effort (like the one that surfaced them) to discover after the fact.
- **Follow-ups:** "Design the minimal CI pipeline that would have caught the most defects discussed in this interview, for the least implementation effort."
- **Common Mistakes:** Treating "no CI" as a generic process gap rather than connecting it concretely to the specific, already-identified bugs it would have prevented.
- **What This Tests:** Connecting an abstract process gap (no CI) to concrete, already-known consequences â€” demonstrating the value of the fix in terms the candidate has already established, not in the abstract.
- **Red Flags:** Discusses CI in generic terms with no connection to this codebase's actual, already-surfaced defects.
- **Excellent Answer:** Designs a minimal pipeline: (1) `pip install` the *corrected* dependency list and confirm `python -c "import app"` succeeds â€” would have caught both the `requirements.txt` issue and the `Optional` import bug immediately; (2) run `pytest test_api.py` against ephemeral test MongoDB/Milvus instances â€” would have caught the `/v1/categorize` regression; (3) a config-validation smoke test per compose file (per DP2) â€” would have caught the environment-variable mismatch. All three are cheap, fast checks that collectively would have caught the majority of this system's most severe known defects.
- **Poor Answer:** Proposes generic CI best practices without mapping them to this codebase's specific known issues.

---

### DP11. If you had to deploy this system today, as-is, with zero code changes, what's the minimum operational workaround needed to make it functional (not secure, just functional)?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Manually install the real dependency set (bypassing `requirements.txt` entirely, as documented in the README), correct `docker-compose_production.yaml`'s environment variable names to match `core/config.py`'s actual requirements (or use a corrected `.env` file instead), and accept that `POST /v1/categorize` remains broken and unusable, since no operational workaround can fix an actual code bug. This gets the *rest* of the system functional without a single code change â€” a genuinely useful distinction between "operational workaround" and "requires a code fix."
- **Follow-ups:** "What's the risk of shipping this operational-workaround-only deployment to real users?"
- **Common Mistakes:** Proposing code changes when the question specifically asks for zero-code-change operational workarounds â€” conflating the two categories.
- **What This Tests:** Whether the candidate respects the actual constraint of the question (operational-only) rather than defaulting to "just fix the code," which tests discipline in scoping an answer to what's actually asked.
- **Red Flags:** Proposes code changes despite the explicit "zero code changes" constraint.
- **Excellent Answer:** Explicitly flags that this workaround-only deployment should still not go to production with real users, since it leaves the hardcoded-API-key and missing-authorization security gaps entirely unaddressed â€” operational functionality and security/production-readiness are separate bars, and clearing the first doesn't clear the second.
- **Poor Answer:** Proposes fixes that require code changes, violating the question's constraint.

---

### DP12. Draw the dependency graph of external services this deployment needs to be "up" simultaneously for a fresh container to successfully start, and explain what happens if each is unavailable.
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** MongoDB must be reachable (or `db.connect()` in `lifespan` would hang/fail, though Motor's client construction itself is lazy and might not fail immediately â€” the first actual query would). Milvus, if unreachable, degrades gracefully after 5 retries (~15s) to a `None` client, allowing startup to continue in a degraded state. Ollama, if unreachable, causes `core/ollama_client.py`'s import-time resolution to raise `RuntimeError`, which â€” because it happens at import time via the `routers.rag` import chain â€” prevents the application from starting at all, not just degrading one feature. So: Ollama is a hard startup dependency; Milvus is a soft one; MongoDB's exact failure mode depends on Motor's specific lazy-connection behavior but is generally also closer to a hard dependency in practice, since nearly every endpoint touches it.
- **Follow-ups:** "Which of these three would you prioritize adding a circuit-breaker or retry-with-backoff pattern to first, and why?"
- **Common Mistakes:** Treating all three dependencies as equally "hard" or equally "soft" without checking each one's actual, verified failure behavior individually.
- **What This Tests:** Synthesizing everything learned across the Architecture and Database categories about each service's specific failure philosophy into one coherent operational picture.
- **Red Flags:** Gives a uniform answer for all three dependencies without differentiating their actual behavior.
- **Excellent Answer:** Prioritizes fixing Ollama's hard-failure-at-import-time behavior first (per Architecture A11's discussion), since it's the one dependency whose current failure mode (crash the whole process) is disproportionate to its actual criticality (only RAG/embedding features need it; categorization, resolution, memory, and most analytics endpoints don't) â€” making it the highest-leverage resilience fix among the three.
- **Poor Answer:** Correctly describes each dependency's behavior in isolation without synthesizing a prioritized recommendation.

