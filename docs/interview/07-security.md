# Security â€” 15 Questions

---

### S1. Rank the top three security findings in this codebase by actual severity, and justify why each ranks where it does.
- **Difficulty:** Expert | **Importance:** 10
- **Expected Answer:** (1) Hardcoded API key ignoring configured settings (`core/security.py`) â€” critical, because it means the entire authentication mechanism is fixed and non-revocable without a code change, and every deployment of this exact code accepts the identical key. (2) Complete absence of an authorization layer â€” critical, because even fixing (1) wouldn't stop any valid caller from accessing any other caller's data (`TEST_USER` hardcoded everywhere). (3) Plaintext credential committed to `docker-compose_production.yaml` â€” critical but narrower in scope, since it's a specific, rotatable secret rather than a structural flaw in the auth mechanism itself.
- **Follow-ups:** "Why does the missing-authorization issue rank as seriously as the hardcoded key, when it's 'just' a missing feature rather than an active leak?"
- **Common Mistakes:** Ranking the committed credential as the single worst finding because it's the most "obviously bad-looking," without weighing that the other two are structural and affect every request, not one specific credential.
- **What This Tests:** Ability to reason about severity in terms of scope and structural impact, not just how alarming a finding looks in isolation.
- **Red Flags:** Ranks findings purely by "how bad does this sound" rather than actual blast radius.
- **Excellent Answer:** Explicitly argues that a missing authorization layer is arguably *worse* long-term than the hardcoded key, because fixing the key alone (making it a real, rotatable secret) would still leave every valid caller with total access to every other caller's data â€” the two findings need to be fixed together to actually secure the system.
- **Poor Answer:** Provides three findings with no comparative severity reasoning.

---

### S2. `services/merchant_resolver.py` builds a MongoDB `$regex` query from user-controlled text. Is this a NoSQL injection vulnerability? Prove your answer by tracing the actual code, not by general principle.
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** No â€” verified not exploitable, but only because of a specific upstream mitigation. `clean_text` runs *before* the text is split into words, and its `special_chars_regex` strips every character that isn't alphanumeric or whitespace. By the time any `word` variable reaches the `{"$regex": f"^{word}", ...}` query, it can only contain letters and digits â€” no regex metacharacters can survive to reach the query construction site. The safety is real today, but depends entirely on this specific function-call ordering continuing to hold.
- **Follow-ups:** "What test would you write to guard against a future regression here?" "Is this pattern (safety-by-upstream-sanitization rather than safety-by-escaping-at-the-query-site) good practice?"
- **Common Mistakes:** Reflexively flagging this as a vulnerability from the "user input reaches a `$regex` query" pattern-match alone, without actually tracing whether the input is sanitized first â€” exactly the failure mode this question is designed to catch.
- **What This Tests:** Whether the candidate does real code tracing under a security-review mindset, versus pattern-matching a known "bad code shape" without verification â€” arguably the single most important skill this whole question bank tests.
- **Red Flags:** Declares this vulnerable without tracing `clean_text`, OR declares it "obviously fine" without being able to explain the specific mechanism that makes it safe.
- **Excellent Answer:** Proposes a regression test: assert that `clean_text("test$where:1==1")` (or any input containing regex/NoSQL metacharacters) produces output containing none of those characters â€” codifying the safety property so a future refactor that reorders `clean_text`'s internal steps, or a new call site that skips `clean_text` entirely, would be caught immediately.
- **Poor Answer:** Either wrongly flags this as vulnerable, or correctly says it's safe with no explanation of the actual mechanism.

---

### S3. What's the actual (not theoretical) risk of the plaintext MongoDB credential committed in `docker-compose_production.yaml`?
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** Anyone with read access to the git repository (or its history â€” deleting the file later doesn't remove it from git history) has the full connection string, including username and password, for whatever MongoDB instance it points to. If that instance is reachable from outside a private network, this is a direct path to full read/write access to all application data. Even if the credential is later rotated, the practice itself (committing secrets to version control) should be treated as a process failure requiring remediation (secret scanning, `.gitignore` discipline, a proper secrets manager), not just a one-time credential rotation.
- **Follow-ups:** "How would you remove this from git history, and why is that harder than just deleting the file?"
- **Common Mistakes:** Treating "just rotate the credential" as a complete fix without addressing the underlying process gap that allowed it to be committed in the first place.
- **What This Tests:** Understanding that a leaked secret in version control is a persistent problem (history), not a point-in-time one.
- **Red Flags:** Doesn't mention git history persistence as a distinct problem from the current file's contents.
- **Excellent Answer:** Notes that rewriting git history (`git filter-repo` or similar) to fully remove the secret is invasive and disruptive for any collaborators with existing clones, so the pragmatic real-world response is almost always "rotate the credential immediately, treat it as permanently exposed, and add secret-scanning tooling going forward" rather than attempting history surgery.
- **Poor Answer:** Proposes only deleting the line from the current file version.

---

### S4. Why is `!=` string comparison for the API key a security code smell even in a system where the current key is already publicly visible in source?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Because the *pattern* itself (non-constant-time secret comparison) is what matters for a code review, independent of today's specific low-severity instance â€” the moment `Vela_API_KEY` is actually wired up to a real, secret value (a fix this codebase clearly needs), this same comparison becomes a genuine timing side-channel. Flagging the pattern now, even when its current instance is low-risk, prevents the same code from becoming a real vulnerability the moment the more obvious bug (hardcoded key) is fixed.
- **Follow-ups:** "Would you block a PR over this today, given the current low severity?"
- **Common Mistakes:** Either dismissing this entirely because "it doesn't matter right now," or treating it as equally urgent as the hardcoded-key issue itself.
- **What This Tests:** Distinguishing "not urgent today" from "not worth fixing" â€” a genuinely important calibration for code review judgment.
- **Red Flags:** Either extreme â€” total dismissal, or false urgency.
- **Excellent Answer:** Recommends fixing both issues (the hardcoded key AND the comparison method) in the same change, since fixing one without the other would leave a newly-real secret protected by a comparison method with a known weakness.
- **Poor Answer:** Addresses only one of the two related issues without connecting them.

---

### S5. Does the absence of CORS middleware in `app.py` constitute a security vulnerability?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Not by itself â€” CORS is a *browser-enforced* restriction that protects users from malicious cross-origin requests made on their behalf using their existing credentials/cookies; its absence doesn't create a server-side vulnerability for an API using header-based (not cookie-based) authentication like this one. It does mean any browser-based frontend calling this API directly would fail, which is a functional gap, not a security one. The security question would only arise if this API used cookie-based session auth, which it does not.
- **Follow-ups:** "Would your answer change if this API used cookies for authentication instead of a header?"
- **Common Mistakes:** Reflexively calling any missing security-adjacent middleware a "vulnerability" without reasoning about the actual threat model.
- **What This Tests:** Correctly scoping what CORS actually protects against, and recognizing when its absence is a functional gap rather than a security hole.
- **Red Flags:** Calls this a vulnerability without engaging with the auth-mechanism-dependent nuance.
- **Excellent Answer:** Explicitly notes that if this API ever switched to cookie-based sessions, CORS (and CSRF protection specifically) would become a real, load-bearing security concern â€” but with the current header-based API key model, a malicious site can't silently "borrow" a user's credentials the way it could with cookies, since the header must be explicitly attached by legitimate client code that already knows the key.
- **Poor Answer:** Treats CORS as inherently a security control regardless of the authentication mechanism in use.

---

### S6. What's the risk of running this application at `logging.DEBUG` level in every environment, from a security standpoint (not just performance)?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** DEBUG-level logs are more likely to include detailed internal state â€” exception messages, potentially request payloads or partial data depending on what any given `logger.debug(...)` call includes â€” that could leak sensitive information into log aggregation systems, which often have broader access (ops teams, third-party log platforms) than the application itself. There's no evidence of secrets being logged directly in this codebase, but the elevated verbosity increases the *surface area* for accidental future leakage as new debug statements are added without review for sensitivity.
- **Follow-ups:** "How would you audit whether any current log statement actually leaks something sensitive?"
- **Common Mistakes:** Claiming secrets are definitely being logged without having verified this â€” the accurate finding is "no confirmed secret leakage found, but the elevated verbosity is a risk multiplier for the future."
- **What This Tests:** Precision about the difference between a confirmed leak and an elevated-risk posture.
- **Red Flags:** Overstates the finding as a confirmed leak without evidence.
- **Excellent Answer:** Proposes a concrete audit method: grep every `logger.debug`/`logger.info` call site for interpolated request bodies, headers, or credentials, cross-referenced against which ones actually execute in this codebase's request paths.
- **Poor Answer:** Vague concern with no proposed verification method.

---

### S7. Why might `OLLAMA_HOSTS` accepting a comma-separated list of arbitrary URLs be worth a security mention, even though it's an operator-controlled configuration value?
- **Difficulty:** Hard | **Importance:** 4
- **Expected Answer:** It's low-risk specifically *because* it's operator-controlled configuration, not user input â€” there's no code path where an API caller can influence which Ollama hosts are tried. It's worth mentioning only as a general configuration-hygiene note: if this value were ever accidentally derived from untrusted input (which it currently isn't), it would be a textbook SSRF (server-side request forgery) vector, since `resolve_ollama_host` makes real outbound HTTP requests to whatever hosts are listed.
- **Follow-ups:** "What would need to change in this codebase for this to become an actual SSRF risk?"
- **Common Mistakes:** Treating this as an active vulnerability today, when it's actually a "watch this if the trust boundary ever changes" observation.
- **What This Tests:** Whether the candidate can correctly identify a *class* of risk relevant to a code pattern without falsely claiming it's currently exploitable.
- **Red Flags:** Claims this is currently exploitable by an external caller.
- **Excellent Answer:** Notes that this would only become real if, say, a future feature let a caller specify or influence an Ollama endpoint per-request (e.g., a multi-tenant deployment routing different tenants to different self-hosted LLMs) â€” worth flagging preemptively as a design constraint for any such future feature, not as a current bug.
- **Poor Answer:** Either dismisses the pattern entirely with no forward-looking awareness, or wrongly claims current exploitability.

---

### S8. This system has no explicit request body size limit on any endpoint. What's the realistic risk, and does it matter equally for every endpoint?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** A caller could send an arbitrarily large `text` field to `/v1/categorize`, `/v1/resolve`, or `/v1/explain`, consuming memory and CPU (regex processing, embedding generation) disproportionate to a legitimate request â€” a low-effort denial-of-service vector. It matters most for `/v1/explain`, since a huge input text flows into an embedding call that itself has real compute cost on the Ollama side, compounding the impact beyond just this application's own memory usage.
- **Follow-ups:** "Where would you enforce a size limit â€” application code, or infrastructure (reverse proxy)?"
- **Common Mistakes:** Treating all endpoints as equally at risk, without recognizing `/v1/explain`'s downstream compute amplification makes it a more attractive target than, say, `/health`.
- **What This Tests:** Threat modeling that accounts for where downstream cost amplification actually occurs, not just "large payloads are bad" in the abstract.
- **Red Flags:** No differentiation between endpoints' relative risk.
- **Excellent Answer:** Recommends enforcing this primarily at the reverse-proxy/infrastructure layer (e.g., Nginx `client_max_body_size`) as the first line of defense, since it protects the application without requiring per-endpoint code changes â€” with an additional application-level `Field(max_length=...)` constraint on `text` fields as defense in depth.
- **Poor Answer:** Proposes only one layer of defense without discussing the trade-off between infrastructure- and application-level enforcement.

---

### S9. Given `requirements.txt` doesn't list this project's actual dependencies, what's the security consequence beyond "the build breaks"?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** There is currently no way to run automated dependency vulnerability scanning (`pip-audit`, Dependabot, Snyk, etc.) against the project's *real* dependency set, since those tools would scan the wrong list entirely (the committed OS-level packages, not `fastapi`/`pymilvus`/`torch`/etc.). This means known CVEs in the actual runtime dependencies could go undetected indefinitely, since the tooling that would normally catch them is scanning the wrong target.
- **Follow-ups:** "How would you fix this and immediately get vulnerability-scanning coverage restored?"
- **Common Mistakes:** Only discussing the build-failure consequence (already covered in other documentation) without connecting it to this distinct, security-specific consequence.
- **What This Tests:** Connecting an already-known operational defect to a *different*, security-specific downstream consequence â€” testing whether the candidate can extend a known finding into new territory rather than just repeating it.
- **Red Flags:** Only restates the build-failure issue without identifying the vulnerability-scanning gap.
- **Excellent Answer:** Proposes generating a correct `requirements.txt` (or migrating to a lockfile format like `poetry.lock`/`pip-compile` output) by cross-referencing every actual `import` statement in the codebase, then immediately running `pip-audit` against it as a one-time catch-up scan before enabling continuous scanning in CI.
- **Poor Answer:** Doesn't identify the vulnerability-scanning gap as a distinct consequence.

---

### S10. Is exposing `/metrics` without authentication a security concern for this specific system?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It leaks operational metadata â€” which routes exist, their relative call volumes, and latency distributions â€” to anyone who can reach the endpoint. For most systems this is a minor, acceptable trade-off for operational convenience (Prometheus scrapers typically shouldn't need application-level credentials), but it does mean an external attacker could use `/metrics` for reconnaissance (e.g., noticing `/v1/categorize` has an unusually high `5xx` rate, hinting at an exploitable bug) if the endpoint is reachable from outside a trusted network.
- **Follow-ups:** "How would you restrict this without breaking Prometheus's ability to scrape it?"
- **Common Mistakes:** Treating this as either "totally fine, it's just metrics" or "a critical vulnerability" â€” the accurate answer is nuanced, situational risk.
- **What This Tests:** Calibrated risk assessment for a genuinely borderline case, rather than a reflexive verdict.
- **Red Flags:** Gives an absolute verdict ("definitely fine" or "definitely a vulnerability") with no situational reasoning.
- **Excellent Answer:** Recommends network-level restriction (only reachable from the Prometheus scraper's IP/internal network) as the standard, low-friction mitigation â€” preserving unauthenticated access for infrastructure while closing the reconnaissance surface to the public internet.
- **Poor Answer:** No concrete mitigation proposed.

---

### S11. If this API were to accept file uploads in the future (it currently doesn't), what security lessons from this codebase's existing patterns would you want to explicitly NOT repeat?
- **Difficulty:** Expert | **Importance:** 6
- **Expected Answer:** Don't repeat: no size limits (S8) â€” file uploads need explicit size caps even more urgently than text fields; the "sanitize once, trust forever" pattern from `merchant_resolver.py` (S2) â€” file content validation should happen at every boundary, not rely on one upstream cleaning step that could be bypassed by a new code path; and the pattern of building any downstream query/command from user-controlled content without an explicit allow-list, mirroring the discipline (even if accidental) that currently keeps the `$regex` construction safe.
- **Follow-ups:** "What NEW risks would file uploads introduce that nothing in this codebase currently has to deal with?"
- **Common Mistakes:** Answering purely about generic file-upload security (virus scanning, content-type validation) without connecting it back to this specific codebase's demonstrated patterns and failure modes.
- **What This Tests:** Whether the candidate can generalize lessons from a specific codebase to a hypothetical new feature, rather than just reciting generic security checklist items.
- **Red Flags:** Gives a generic file-upload security answer with zero connection to anything actually observed in this codebase.
- **Excellent Answer:** Also names genuinely new risks unique to file uploads (path traversal in filenames, decompression bombs, storage exhaustion) that have no analog anywhere in this codebase's current text-only input surface.
- **Poor Answer:** Entirely generic, textbook file-upload-security answer.

---

### S12. Why is "the current API key is publicly visible in the source code" actually a useful fact for prioritizing remediation, not just an embarrassing detail?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It tells you the *current* real-world exploitability is effectively total (anyone with repo access already has full API access) but also that this specific credential's blast radius is capped at whatever this pre-production system currently protects â€” it's not a "someone might guess this" risk, it's a "everyone already has it" fact, which should shape messaging: this isn't a subtle risk to be quietly patched, it's an already-realized exposure that must be fixed before any real data or production use, not treated as a nice-to-have hardening task.
- **Follow-ups:** "How does this change your remediation timeline recommendation compared to a genuinely secret-but-weak key?"
- **Common Mistakes:** Treating "the key is visible in source" and "the key is weak/guessable" as the same category of problem â€” they have different implications for urgency and messaging.
- **What This Tests:** Ability to translate a technical fact into an accurate urgency/priority signal for stakeholders.
- **Red Flags:** Doesn't distinguish "known to everyone" from "theoretically guessable."
- **Excellent Answer:** Frames this as "not a vulnerability to patch before it's exploited â€” it's already fully exploited by definition, for anyone who's seen this repository," which should escalate urgency above a typical "medium-severity, schedule for next sprint" bug.
- **Poor Answer:** Treats this the same as any other generic authentication weakness with no urgency distinction.

---

### S13. What security testing would you add to `test_api.py` that doesn't exist today?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Today's `test_security_missing_key` only checks that a missing key is rejected â€” nothing tests that a *tampered* or *slightly-modified* key is rejected (e.g., `"Vela_test_key_123 "` with trailing whitespace, or a key differing by one character), nothing verifies the regex-injection safety property discussed in S2 with an actual malicious-looking input, and nothing tests that one caller can't access another caller's data (impossible to test meaningfully today, since there's no per-caller data separation to test in the first place â€” which is itself a finding worth stating).
- **Follow-ups:** "Which of these would you prioritize adding first?"
- **Common Mistakes:** Proposing generic security tests (SQL injection, XSS) that don't apply to this specific codebase's actual attack surface (no SQL, no server-rendered HTML).
- **What This Tests:** Whether proposed tests are grounded in this system's actual architecture and known findings, not a generic security-testing checklist.
- **Red Flags:** Proposes tests for vulnerability classes that don't apply to this system's actual technology (e.g., XSS tests for a pure JSON API with no HTML rendering).
- **Excellent Answer:** Prioritizes the regex-injection regression test (S2) first, since it's the cheapest to write and directly protects an already-identified, currently-fragile safety property â€” versus the multi-tenancy isolation test, which can't even be written meaningfully until the underlying authorization gap is fixed.
- **Poor Answer:** Lists generic security test ideas without prioritization or connection to this codebase's actual findings.

---

### S14. A junior engineer proposes fixing the hardcoded API key by moving it to an environment variable that's already... also hardcoded as a default value with no override validation. Why is this not a real fix?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** If the "fix" simply changes `if api_key_header != "Vela_test_key_123":` to `if api_key_header != os.getenv("Vela_API_KEY", "Vela_test_key_123"):` â€” with the same value as a fallback default â€” the security posture is identical: anyone who fails to explicitly set the environment variable (an easy oversight) silently falls back to the exact same known, public value. A real fix must make `Vela_API_KEY` a required setting with *no* default (which `core/config.py`'s `Settings` model already correctly does â€” it's declared without a default, meaning the app already fails to start without it) and use that already-correctly-configured setting, not reintroduce a fallback.
- **Follow-ups:** "Does `core/config.py` already get this part right, independent of `core/security.py`'s bug?"
- **Common Mistakes:** Accepting "moved it to an env var" as sufficient progress without checking whether a default value undermines the fix.
- **What This Tests:** Scrutinizing a proposed fix for the exact same flaw it claims to solve â€” a realistic code-review scenario.
- **Red Flags:** Approves the proposed "fix" without checking for a fallback default.
- **Excellent Answer:** Notes that `core/config.py`'s `Vela_API_KEY: str` (no default) is actually already correctly strict â€” the real fix is simply to make `core/security.py` read `settings.Vela_API_KEY` directly, inheriting that existing strictness, rather than reimplementing environment-variable access with a new, weaker fallback.
- **Poor Answer:** Doesn't recognize the proposed fix reintroduces the same vulnerability under a different mechanism.

---

### S15. Write the one paragraph you'd include in a pre-deployment sign-off document explaining why this system should NOT go to production with real user data today.
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** A strong paragraph names, together, in order of severity: (1) authentication accepts a single hardcoded key regardless of configuration, giving any holder of the (source-visible) key full API access; (2) there is no authorization layer at all â€” every valid caller sees identical, undifferentiated data (`TEST_USER` hardcoded across analytics), meaning real multi-user data isolation does not exist; (3) a real infrastructure credential is committed in plaintext to version control. Together, these mean any real user's financial transaction data placed into this system today would be accessible to any other caller with the public test key, with no way to audit who accessed what.
- **Follow-ups:** "Which of these three would you demand be fixed before ANY other pending feature work, and why?"
- **Common Mistakes:** Writing a paragraph focused on only one finding, missing the compounding effect of all three together.
- **What This Tests:** Synthesis across the entire security review into one decision-grade statement â€” the actual deliverable expected from a senior engineer signing off on a production readiness review.
- **Red Flags:** Produces a vague, non-committal paragraph that wouldn't actually justify blocking a deployment decision.
- **Excellent Answer:** Explicitly states that (1) and (2) must be fixed together â€” fixing the hardcoded key alone still leaves every caller with universal data access â€” and that this combination should be treated as an unconditional launch blocker, not a "fix in the next sprint" backlog item.
- **Poor Answer:** Lists the findings without connecting them into a single, prioritized, decision-oriented recommendation.

