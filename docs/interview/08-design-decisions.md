# Design Decisions — 15 Questions

---

### DD1. Explain the "Unknown is a valid answer" philosophy behind the confidence wall. Why is this a genuinely good design decision for a financial system?
- **Difficulty:** Medium | **Importance:** 9
- **Expected Answer:** `engines/confidence_engine.py::evaluate` deliberately forces any prediction below a 0.5 threshold, or any category outside the known vocabulary, to `Unknown` rather than passing through a low-confidence guess. In a financial categorization system, a wrong-but-confident-looking category (e.g., miscategorizing a large transfer as "Entertainment") is worse than an honest "we don't know," because downstream consumers (analytics, RAG explanations) implicitly trust whatever category they're given — propagating false confidence corrupts everything built on top of it.
- **Follow-ups:** "What's the cost of this design — what does the system lose by being this conservative?"
- **Common Mistakes:** Praising the philosophy without acknowledging its real trade-off (reduced coverage/usefulness in exchange for correctness).
- **What This Tests:** Whether the candidate can articulate *why* a design choice is good, not just that it exists, and can name its honest trade-off.
- **Red Flags:** Can't explain why a wrong-but-confident answer is worse than an honest unknown for this specific domain.
- **Excellent Answer:** Names the concrete cost: a system this conservative will produce more `Unknown` results than a less careful one, which could frustrate users wanting complete categorization — a real product trade-off between correctness and coverage, not a free win.
- **Poor Answer:** Restates the mechanism without evaluating its trade-offs.

---

### DD2. Why are the memory state machine's thresholds set at exactly 3 (TEMPORARY) and 10 (PERMANENT) encounters, and how would you evaluate whether these are the right numbers?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** No empirical justification exists anywhere in the codebase — these are hardcoded constants in `memory/state_machine.py::StateMachine.__init__` with no accompanying analysis, A/B test, or reference to real user behavior data. Evaluating whether they're correct would require analyzing real (or realistic simulated) encounter-frequency distributions to see whether 3/10 actually separates "probably a fluke" from "probably a recurring merchant" for this specific domain (personal financial transactions).
- **Follow-ups:** "What data would you want before changing these numbers?" "What's the risk of getting them wrong in each direction?"
- **Common Mistakes:** Assuming these numbers must be well-justified simply because they're specific integers rather than round numbers like "5" or "20."
- **What This Tests:** Whether the candidate distinguishes "this looks deliberate" from "this is actually validated."
- **Red Flags:** Assumes 3/10 are empirically derived without any evidence in the code.
- **Excellent Answer:** Articulates the two-sided risk clearly: thresholds too low mean untrustworthy/noisy entities get promoted too fast (undermining the whole point of the trust system); too high means genuinely recurring merchants stay under-trusted too long, delaying features (like behavior profiling in some hypothetical future integration) that depend on `PERMANENT` status.
- **Poor Answer:** Only discusses one side of the risk, or none.

---

### DD3. Why does the memory manager wake an `ARCHIVED` profile directly to `TEMPORARY` rather than back to `EPHEMERAL`, and without resetting its frequency?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** The design encodes an implicit belief: an entity that was previously trusted enough to reach any state (even one that later decayed to `ARCHIVED`) and is now being seen again shouldn't have to fully re-earn trust from zero — its prior history is still meaningful evidence, even after a long gap. Not resetting `frequency` preserves that accumulated evidence, at the cost of allowing a reactivated profile to jump quickly back toward `PERMANENT`.
- **Follow-ups:** "Is that the right trade-off? What would you ask a product owner to clarify?"
- **Common Mistakes:** Assuming this must be a bug because it doesn't match "reset to zero on decay" intuition, without first considering the plausible product rationale.
- **What This Tests:** Empathy for design intent before jumping to "this is wrong" — a mark of a thoughtful reviewer versus a reflexive critic.
- **Red Flags:** Declares this definitively wrong without considering the plausible intentional rationale first.
- **Excellent Answer:** Proposes the exact clarifying question a good engineer would ask a product owner: "should a merchant we haven't seen in over 180 days be treated with the same trust as one we've seen consistently, once it reappears?" — surfacing the ambiguity rather than unilaterally resolving it.
- **Poor Answer:** Treats this purely as an obvious defect with no engagement with the underlying product question.

---

### DD4. Why does the RAG explanation pipeline format context as pseudo-XML (`<MERCHANT_DATA>`) instead of just embedding JSON in the prompt?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Clear, visually distinctive delimiters like `<MERCHANT_DATA>`/`<NAME>` are believed to help a language model distinguish structured reference data from conversational instructions in the same prompt — a common prompt-engineering heuristic, though not something this codebase validates empirically (no A/B test or evaluation comparing this format against a JSON-in-prompt alternative exists).
- **Follow-ups:** "How would you actually test whether this formatting choice measurably improves output quality?"
- **Common Mistakes:** Treating this as a proven-optimal choice rather than a reasonable, unvalidated heuristic.
- **What This Tests:** Distinguishing "a plausible design choice" from "an empirically validated one" — the same discipline tested in DD2.
- **Red Flags:** Asserts this format is definitively superior with no acknowledgment that it's untested in this codebase.
- **Excellent Answer:** Proposes a concrete evaluation: run the same set of test queries through both a JSON-formatted and an XML-formatted prompt, using `evaluation/metrics.py`-style human or automated grading of explanation quality/faithfulness, to actually validate the assumption rather than trusting folklore.
- **Poor Answer:** No proposed way to actually validate the choice.

---

### DD5. Why does `rag/generator.py` use both a strict system prompt AND Ollama's structured-output mode (`format: "json"`), when either alone might seem sufficient?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** They provide defense in depth against different failure modes — the system prompt aims to constrain *content* (don't hallucinate, don't act conversational, only use provided context), which the model can still fail to follow despite being told; `format: "json"` is a decoding-level guarantee enforced by Ollama itself, ensuring syntactic validity regardless of what the model "wants" to output. Neither alone would fully solve the problem the other addresses.
- **Follow-ups:** "Which of the two layers would you keep if you could only have one, and why?"
- **Common Mistakes:** Treating this as redundant belt-and-suspenders engineering rather than recognizing the two mechanisms guard against genuinely different failure classes.
- **What This Tests:** Understanding layered defenses aren't automatically redundant just because they're both "trying to ensure good output."
- **Red Flags:** Calls one of the two layers unnecessary without correctly identifying what each specifically guards against.
- **Excellent Answer:** Argues for keeping `format: "json"` if forced to choose, since a syntax failure (unparseable output) breaks the entire response handling code (`json.loads` would raise), whereas a content failure (a subtly wrong but valid-JSON explanation) at least degrades gracefully into a usable, if imperfect, response.
- **Poor Answer:** Picks one layer to discard without justifying the choice against actual failure-mode severity.

---

### DD6. Why is the grounding check ("do we have real context?") implemented as a sentinel string (`"NO_CONTEXT_AVAILABLE"`) rather than, say, `None` or an empty string?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** A distinctive, unambiguous, hard-to-confuse-with-real-data string that `rag/generator.py` can reliably check for with a simple, unambiguous equality comparison. Using `None` would work too but requires every intermediate function signature to accept `Optional[str]`; an empty string risks being confused with other legitimate "empty but not sentinel" states elsewhere in a codebase that isn't rigorous about that distinction everywhere.
- **Follow-ups:** "What's a more idiomatic Python alternative to a sentinel string, and would it be better here?"
- **Common Mistakes:** Dismissing sentinel strings as inherently bad practice without weighing them against the specific alternatives in this specific context.
- **What This Tests:** Balanced evaluation of a common but sometimes-maligned pattern (magic strings) in its actual context of use.
- **Red Flags:** Blanket statement that "magic strings are always bad" with no situational reasoning.
- **Excellent Answer:** Proposes a more idiomatic alternative — a small dataclass or a `Result`-style type (`Ok(context)` / `NoContext()`) — while acknowledging that for a two-function internal pipeline like this one, the sentinel string is a pragmatic, low-ceremony choice that isn't actually causing any observed bugs.
- **Poor Answer:** Only criticizes without offering or weighing an alternative.

---

### DD7. Why does this codebase favor "return an empty list/dict and log a warning" over raising exceptions in most of its I/O-heavy code (Milvus search, RAG retrieval)?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** It's a deliberate graceful-degradation philosophy — a failure in semantic search or context retrieval should degrade the RAG pipeline to "no context available" (a safe, still-useful response) rather than causing a hard 500 error for the entire `/v1/explain` request. The trade-off, as discussed elsewhere, is that genuine infrastructure failures become indistinguishable from legitimate "nothing matched" results without checking logs.
- **Follow-ups:** "Is this philosophy applied consistently across the whole codebase, or only in some places?"
- **Common Mistakes:** Assuming this is a universal pattern across the codebase — it isn't; `behaviour/behavior_engine.py` raises `ValueError` on empty data instead of degrading gracefully, an inconsistency worth naming.
- **What This Tests:** Recognizing that even a good philosophy can be applied inconsistently, and noticing that inconsistency.
- **Red Flags:** Claims uniform application of this pattern without checking counterexamples.
- **Excellent Answer:** Explicitly contrasts the RAG/Milvus graceful-degradation pattern against `behaviour/behavior_engine.py`'s explicit-exception pattern, and reasons about why each might be appropriate in its own context (RAG's failure mode should be invisible to a user asking a question; behavior profiling's failure mode should be loud to whoever triggered it, since it's an operator-invoked batch job, not a live user-facing request).
- **Poor Answer:** Describes only one pattern without contrasting it against the other.

---

### DD8. Why does this codebase use module-level singletons everywhere instead of a dependency-injection framework or FastAPI's own `Depends()` system for services?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Simplicity — one line per service (`rule_engine = RuleEngine()`) with zero configuration/wiring overhead, versus the additional structure a DI framework or consistent `Depends()`-based service injection would require. The trade-off, discussed at length elsewhere, is no test-isolation seam and implicit rather than explicit dependencies (visible only by reading imports, not function signatures).
- **Follow-ups:** "At what team size or codebase complexity would you argue this trade-off stops being worth it?"
- **Common Mistakes:** Treating singletons as an accidental pattern rather than a deliberate (if perhaps under-examined) simplicity choice.
- **What This Tests:** Recognizing that "simple" and "worse" aren't synonyms — this pattern has genuine merits for a small, single-team codebase.
- **Red Flags:** Treats the singleton pattern as unambiguously wrong architecture with no situational nuance.
- **Excellent Answer:** Argues this becomes a real liability specifically once test coverage needs to grow (mocking becomes painful) or once the team grows large enough that implicit dependencies (only visible via import statements) start causing onboarding friction — neither of which this codebase has clearly hit yet, given it has essentially one test file and, presumably, a small team.
- **Poor Answer:** No situational threshold offered — treats the pattern as either always fine or always bad.

---

### DD9. Why might using two separate databases (MongoDB + Milvus) instead of a single database with native vector-search support (e.g., MongoDB Atlas Vector Search, or Postgres with pgvector) be a defensible choice — or not?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Milvus is a purpose-built vector database with more mature, tunable approximate-nearest-neighbor indexing (HNSW with configurable `M`/`efConstruction`/`ef`) than most general-purpose databases' bolted-on vector features offer, which is a real argument in its favor for search quality/performance at scale. The cost is exactly what this codebase demonstrates: operational complexity (two systems to run, monitor, and keep in sync) and, concretely, the duplicate-client and dual-write-consistency problems already documented — costs that a single unified database would eliminate entirely.
- **Follow-ups:** "Given this specific codebase's current scale and maturity, would you recommend consolidating onto one database?"
- **Common Mistakes:** Treating "purpose-built is always better" or "fewer systems is always simpler" as universally true without weighing them against each other for this specific system's actual needs.
- **What This Tests:** Balanced architectural trade-off reasoning about a genuinely debatable, non-obvious decision.
- **Red Flags:** Picks a side dogmatically without acknowledging the counter-argument.
- **Excellent Answer:** Recommends consolidation for *this specific system's current state* — the operational cost of two databases has already manifested as real bugs (duplicate Milvus clients, an entirely unwired write path) with no evidence the vector-search workload has outgrown what a single-database solution could handle — while acknowledging a larger-scale, dedicated vector-search-heavy system might justify Milvus's added complexity.
- **Poor Answer:** Recommends one option with no connection to this specific codebase's demonstrated pain points.

---

### DD10. Why do `engines/rule_engine.py` and `services/merchant_resolver.py` remain two separate systems rather than being unified, given they solve overlapping problems?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Almost certainly organic — different development phases (1-2 vs. 3) with different data sources and matching strategies, never revisited for consolidation. The rule engine's own code comments even point toward the resolver's eventual Milvus-based semantic-search successor as the intended long-term direction, suggesting the original author was aware unification (or replacement) was the "right" eventual answer but never executed it.
- **Follow-ups:** "If you were to unify them today, would you keep both matching strategies, or pick one?"
- **Common Mistakes:** Assuming there must be a principled reason they're separate (e.g., "one is for X kind of input, one is for Y") without verifying that distinction actually holds in the code.
- **What This Tests:** Whether the candidate distinguishes "historically explicable" from "currently justified" — two systems can coexist because of history without that coexistence being the right long-term state.
- **Red Flags:** Invents a principled technical distinction that doesn't survive scrutiny of the actual code.
- **Excellent Answer:** Proposes a concrete unification path: keep the resolver's database-backed, confidence-graded approach as the primary path (it's more flexible and already designed for a confidence ladder), and fold the rule engine's static alias dictionary in as a fast, in-memory first-pass cache layer in front of it, rather than a fully separate, disconnected system.
- **Poor Answer:** Suggests "just delete one" without weighing what capability would be lost.

---

### DD11. Why does the codebase organize business logic into five differently-named folders (`engines/`, `services/`, `memory/`, `analytics/`, `rag/`) instead of one `services/` folder for everything?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** No evidence of a deliberate naming taxonomy — checked against the actual code, the names don't reliably correlate with any consistent technical distinction (sync vs async, stateless vs stateful, I/O vs pure). It's most likely organic naming drift across different phases/contributors rather than an intentional information architecture.
- **Follow-ups:** "If you were designing this from scratch today, what naming convention would you choose, and why?"
- **Common Mistakes:** Inventing and defending a naming rule that doesn't actually hold up against a check of the real code (same failure mode as Architecture A5 — worth testing again here to see if the candidate is consistent).
- **What This Tests:** Consistency of judgment — does the candidate apply the same "verify before asserting" discipline here as elsewhere in the interview.
- **Red Flags:** Confidently states a naming rule without having verified it holds for every folder.
- **Excellent Answer:** Proposes a concrete, checkable convention for a hypothetical rewrite — e.g., group by *phase/feature* (as the current folder structure already loosely does) rather than by architectural role, since the phase-based grouping is at least consistently checkable against the code's own "Phase N" comments, unlike a role-based naming scheme that doesn't hold up.
- **Poor Answer:** Proposes a new naming scheme with no acknowledgment that the current one isn't principled.

---

### DD12. Why might it be a deliberate (even if under-examined) choice that `merchant_profiles.confidence` exists in the schema but is never actually set to anything meaningful?
- **Difficulty:** Hard | **Importance:** 4
- **Expected Answer:** Plausibly a forward-looking placeholder — the field was added in anticipation of a future feature (perhaps an aggregate trust/confidence score derived from a merchant's categorization history) that was never actually built, rather than a mistake in the current, narrower feature set. This is a common and often reasonable pattern (reserving a field for known future needs) as long as it's clearly understood to be unimplemented rather than assumed to be silently working.
- **Follow-ups:** "What's the risk of leaving unimplemented-but-present fields like this in a schema without documentation?"
- **Common Mistakes:** Assuming this must be either "definitely intentional forward design" or "definitely a bug" with high confidence either way, when the honest answer is genuine uncertainty without access to the original design intent.
- **What This Tests:** Comfort expressing calibrated uncertainty rather than false confidence about unknowable intent.
- **Red Flags:** States with certainty what the original author intended, with no hedging.
- **Excellent Answer:** Notes the real risk regardless of original intent: any new engineer reading `MerchantProfile.confidence: float = 0.0` would reasonably assume it reflects something meaningful today, when it doesn't — an argument for either implementing the feature, removing the field, or at minimum documenting it as reserved/unimplemented.
- **Poor Answer:** Confidently asserts original intent with no hedge, and no discussion of the documentation risk either way.

---

### DD13. Why is `POST /v1/analytics/anomaly/check` a `POST` request that takes query parameters instead of a JSON body?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** No technical requirement forces this — FastAPI supports query parameters on any HTTP method — but it's inconsistent with every other `POST` endpoint in this codebase, all of which use a JSON request body. It's most likely simply how the function signature (`merchant: str, amount: float` as plain parameters rather than a Pydantic model) happened to be written, without following the established convention.
- **Follow-ups:** "Does this inconsistency actually cause any functional problem, or is it purely stylistic?"
- **Common Mistakes:** Inventing a justification (e.g., "it's a lightweight check so query params make sense") that isn't reflected in any stated design rationale in the code.
- **What This Tests:** Willingness to call an inconsistency "just an inconsistency" rather than manufacturing false design intent.
- **Red Flags:** Confidently defends this as an intentional, principled choice.
- **Excellent Answer:** Notes it's purely stylistic with no functional bug resulting — but flags it as exactly the kind of small inconsistency that erodes an API's predictability for consumers, who now can't assume "every POST here takes a JSON body."
- **Poor Answer:** Invents a rationale not supported by the code or any comment.

---

### DD14. This codebase names its development stages "Phases" in code comments. What's the design value of this convention, and what's its cost once phases become disconnected?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Value: it creates a clear, traceable narrative connecting code to a roadmap, making it easy to explain "what does this do" in terms of a numbered sequence (and this entire documentation effort leaned on exactly that convention to organize itself). Cost: once phases stop being wired together end-to-end (as happened for 8, 9, 10, 11, 14), the phase numbering starts implying a false sense of sequential completeness — reading "Phase 8: Clustering" suggests it's a finished, working stage, when it's actually non-functional.
- **Follow-ups:** "Would you keep this convention, drop it, or change how it's used, for a hypothetical Phase 16?"
- **Common Mistakes:** Treating the phase convention as purely positive or purely misleading, without acknowledging both the genuine organizational value and the real risk of implying false completeness.
- **What This Tests:** Balanced evaluation of a documentation/naming convention's dual nature.
- **Red Flags:** One-sided assessment (only praise or only criticism).
- **Excellent Answer:** Proposes keeping the convention but supplementing it with an explicit status marker in the same comments (e.g., `# Phase 8 Endpoint [STATUS: BROKEN, see issue #...]`) so the numbering's narrative value is preserved without implying unverified completeness.
- **Poor Answer:** Only evaluates the convention from one angle.

---

### DD15. If you had to defend this codebase's overall architectural philosophy to a skeptical staff engineer in one sentence, what would you say — and what would you concede?
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** A strong defense: "The core domain logic — the confidence wall, the trust state machine, the grounded RAG pipeline — reflects genuinely sound, thoughtful design for the hard problem of trustworthy financial categorization, even though the surrounding execution (wiring, testing, data-layer consistency) hasn't caught up to that design quality yet." The concession: several features exist as isolated, correct-in-a-vacuum code with no live callers, and the gap between "designed" and "actually running end-to-end" is this codebase's single biggest weakness.
- **Follow-ups:** "Which specific piece of domain logic would you point to as the strongest evidence for your defense?"
- **Common Mistakes:** Either an uncritical defense (ignoring the very real, extensively documented gaps) or a purely critical dismissal (ignoring the genuinely good ideas underneath the execution gaps) — both fail to synthesize the whole picture accurately.
- **What This Tests:** The single hardest synthesis question in this category — can the candidate hold both "this has real architectural merit" and "this has serious execution gaps" as simultaneously true, and communicate that nuance persuasively to a skeptical audience.
- **Red Flags:** One-dimensional answer in either direction.
- **Excellent Answer:** Points specifically to the confidence wall's "Unknown is a valid answer" principle as the strongest evidence of genuine domain thoughtfulness — a design choice that actively trades away coverage for correctness, which is exactly the kind of decision a less careful team wouldn't have made — while conceding that the same team never went back to verify that this well-designed core logic is actually reachable end-to-end for a meaningful fraction of the system's intended features.
- **Poor Answer:** A one-line, unnuanced verdict without a specific supporting example on either side.
