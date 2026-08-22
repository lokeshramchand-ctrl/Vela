# Vela â€” Senior Engineer Interview Question Bank

> **Note on currency**: these questions were written against an earlier snapshot of the codebase and many reference bugs that have since been fixed (see [`docs/16-known-issues-tech-debt.md`](../16-known-issues-tech-debt.md) for current status). They still work well as interview material â€” "what was wrong and how would you fix it" is a fine question whether or not the fix has since landed â€” just don't assume every bug referenced below is still present in the code today.

204 questions, organized into 13 categories, generated entirely from this codebase's actual implementation â€” every question references a real file, function, bug, or design decision documented elsewhere in `/docs`. None of these are generic framework trivia; if you can't answer a question by reasoning about *this specific code*, that's the point.

## Two honest deviations from a generic template

- **"Frontend"** â€” this repository contains **no frontend code at all** (confirmed across every prior documentation pass: no HTML, JS, templates, or static assets beyond one banner image). Rather than invent frontend questions about code that doesn't exist, this category is reframed as **"Frontend / Client Integration"** â€” testing whether a candidate can reason about what Vela's actual API contract, auth model, and response inconsistencies imply for *any* client that would consume it (browser, mobile, or another backend).
- **"State Management"** â€” not React/Redux state. Vela has a genuine, first-class domain state machine (the Phase 4 memory engine: `EPHEMERAL â†’ TEMPORARY â†’ PERMANENT â†’ ARCHIVED`), plus several architectural "state" patterns worth interrogating (singletons as implicit application state, in-memory rate-limiter state, an in-memory graph that's lost on restart). This category tests understanding of *that*.

## How to use this bank

Each question includes:
| Field | Purpose |
|---|---|
| **Difficulty** | Easy / Medium / Hard / Expert |
| **Importance** | 1â€“10 â€” how load-bearing this concept is to understanding the system correctly |
| **Expected Answer** | What a candidate who has genuinely read and understood this code would say |
| **Follow-ups** | Where an interviewer would push next |
| **Common Mistakes** | What most candidates get wrong, and why |
| **What This Tests** | The underlying competency being probed, beyond the surface question |
| **Red Flags** | Answers that indicate the candidate is guessing, pattern-matching from generic knowledge, or hasn't actually read the code |
| **Excellent Answer** | What separates a senior-level response from a merely correct one |
| **Poor Answer** | A concrete example of a response that sounds plausible but is wrong or shallow |

## Category index

| # | Category | Count | File |
|---|---|---|---|
| 1 | Architecture | 20 | [01-architecture.md](./01-architecture.md) |
| 2 | Frontend / Client Integration | 8 | [02-frontend-client-integration.md](./02-frontend-client-integration.md) |
| 3 | Backend | 25 | [03-backend.md](./03-backend.md) |
| 4 | Database | 25 | [04-database.md](./04-database.md) |
| 5 | Authentication | 15 | [05-authentication.md](./05-authentication.md) |
| 6 | Performance | 15 | [06-performance.md](./06-performance.md) |
| 7 | Security | 15 | [07-security.md](./07-security.md) |
| 8 | Design Decisions | 15 | [08-design-decisions.md](./08-design-decisions.md) |
| 9 | API | 15 | [09-api.md](./09-api.md) |
| 10 | State Management | 12 | [10-state-management.md](./10-state-management.md) |
| 11 | Deployment | 12 | [11-deployment.md](./11-deployment.md) |
| 12 | Scaling | 12 | [12-scaling.md](./12-scaling.md) |
| 13 | Edge Cases | 15 | [13-edge-cases.md](./13-edge-cases.md) |
| | **Total** | **204** | |

## Suggested interview structure

A 60-minute senior-level system interview using this bank might draw: 2 Architecture, 3 Backend, 3 Database, 2 Authentication, 2 Security, 2 Design Decisions, 1 API, 1 State Management, 1 Edge Case â€” roughly 17 questions, weighted toward the categories where this codebase has the most genuine depth (Backend and Database), using Follow-ups to go deeper on whichever 3-4 the candidate answers best.

## Related documents
Every question here is traceable to a specific finding in [`docs/16-known-issues-tech-debt.md`](../16-known-issues-tech-debt.md), [`docs/17-senior-architect-review.md`](../17-senior-architect-review.md), [`docs/18-database-analysis.md`](../18-database-analysis.md), or the per-file/per-folder/per-endpoint references. Where a question is about a bug, the doc citation is the answer key.

