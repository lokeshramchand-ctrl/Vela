# Phase 15: privacy/security qualification

## Findings

### 1. Two real personal Google Pay statements were tracked in git (fixed)

- `assets/gpay_statement_20260201_20260731.pdf` (found during Phase 7):
  contains a real phone number, email address, and real counterparty
  names. Tracked since the Wave 6 commit, present on `master` and every
  wave branch pushed to `origin`.
- `mock/gpay_statement_20260101_20260630.pdf` (found during this phase):
  the *same* real phone number and email, despite the `mock/` directory
  name implying a synthetic fixture. Tracked since the very first `wave1`
  commit - present on `master` and every wave branch.

**Action taken (per explicit user direction):** both added to
`.gitignore` and untracked via `git rm --cached` - kept on disk locally so
the regression tests that use them keep working for local development, but
no longer committed going forward. Every test that opens either file is
now guarded with `unittest.skipUnless(os.path.exists(...))`, verified both
ways: all pass when the files are present, and the dependent tests skip
(not fail) when they're absent - confirmed by physically removing both
files and rerunning the suite (27 passed / 7 skipped) before restoring
them.

**Not done, and why:** git history was not rewritten. Both files remain
recoverable from every commit before this branch's untracking commits, on
every branch that already has them, including `master` and everything
already pushed to `origin`. Untracking stops *future* commits from
carrying the file forward; it does not remove it from history. Rewriting
history (`git filter-repo`, force-push) is a hard-to-reverse, shared-state-
affecting action this task explicitly reserves for explicit user
authorization - it wasn't requested, so it wasn't done. **If full removal
from history and the remote is wanted, that requires a separate, explicit
decision** (likely `git filter-repo` plus a coordinated force-push across
every branch that has it, which rewrites commit hashes app-repo-wide and
would need any collaborator/CI cache to be aware).

### 2. Logging sweep

Grepped every `logger.*` call in `statements/`, `services/`,
`repositories/`, `ai_resolution/`, `routers/` for merchant/counterparty/
amount/PII-shaped arguments. Only two call sites log merchant names
(`statements/statement_service.py:144,168`, `routers/pipelines.py:88`) and
both log the *canonical* merchant name (e.g. `"Amazon"`) used as a
behavior-profiling key, not `counterparty_raw` (the raw "Paid to X" text,
which for P2P transfers can be a real person's name) or `raw_text`.
Grepped separately for any logging of `raw_text`/`counterparty` directly:
zero hits anywhere in the backend.

### 3. Secrets sweep

- `.env` is gitignored and not tracked (confirmed via `git ls-files`).
- A quick pattern sweep for AWS-key-shaped and OpenAI-key-shaped strings
  across every tracked file: zero hits. CI's dedicated `gitleaks` job
  (`.github/workflows/ci.yml`) is the authoritative, comprehensive check
  for this - this was a supplementary spot-check, not a replacement for
  it.

### 4. Test fixtures / generated reports

- Every new test/doc/report added across Phases 1-14 was written to
  assert on *structural* properties (counts, field presence, date ranges,
  reconciliation totals) rather than printing or asserting specific
  transaction content - confirmed by grep: no `lokeshramchand` or the real
  phone number appears in anything this branch has committed to
  `docs/` or `evaluation/`.
- `evaluation/test_edge_cases.py`'s pre-existing determinism test
  (`test_parsing_the_same_upload_twice_is_deterministic`) does compare
  tuples containing `counterparty_raw` for equality - on assertion
  *failure* pytest would print that diff to the local console. Since this
  test only runs locally now (skipped in CI, since the file is gitignored
  there), this is no longer a CI-log exposure risk; on the user's own
  machine against their own data it's not a third-party exposure either.

### 5. Temporary files

Traced in Phase 5: the upload path is entirely `io.BytesIO`-based, nothing
in `routers/statements.py` or `statements/pdf_parser.py` ever writes to a
temp file, so there's nothing to clean up or leak via a stale temp file.

## What wasn't checked

- Frontend (Flutter) responses/logs - out of scope for this backend-
  focused branch, not audited.
- Database records - no live MongoDB was available in this sandbox
  (Phase 6's honest caveat applies here too); whether real data has ever
  landed in a deployed MongoDB instance wasn't and couldn't be checked
  here.
- Whether the real statements were exposed *before* this phase (e.g.
  already cloned by a collaborator, cached by GitHub, indexed by a
  third-party scraper) - untracking going forward doesn't retroactively
  address any exposure that already happened while the files were
  tracked and pushed.
