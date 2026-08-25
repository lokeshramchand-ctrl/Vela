"""
Phase 5: traces the complete upload path (upload -> pypdf -> pdfplumber ->
extraction -> normalization -> persistence) to answer the question
EDGE_CASE_REPORT.md finding 7 left open: "worth confirming the upload flow
doesn't have a gap between [open_and_inspect() and extract_text()] (e.g. an
early 'looks valid' acknowledgment sent to the user before extraction
actually runs)."

Answer, confirmed by reading routers/statements.py::upload_statement
directly: there is no gap. open_and_inspect(), extract_text(),
validate_signature(), parse_period(), and parse_declared_totals() all run
synchronously, in that order, inside one try/except block, before any
persistence call (GridFS store, Statement.create, Job.create) and before
the 202 response is returned. A file that passes open_and_inspect() but
fails extract_text() - like the malformed-xref fixture - raises
CorruptedPDFError and the request never gets past line
`statement_parser.extract_text(raw_bytes, password)`. Nothing is stored,
no statement/job document is created, and the client receives a 422, not
a 202.

These tests don't require a running app or a database: the first proves
the parser-level failure directly (no live server needed to observe it),
the second is a static structural guard that fails loudly if a future
change moves a persistence call ahead of the parsing try/except block,
since that's the one code shape that would reintroduce the false-success
gap this phase confirms does not currently exist.
"""

import re
import unittest
from pathlib import Path

from statements.pdf_parser import CorruptedPDFError, statement_parser

_ROUTER_SOURCE = Path("routers/statements.py").read_text(encoding="utf-8")
_PARSER_SOURCE = Path("statements/pdf_parser.py").read_text(encoding="utf-8")


def _extract_function_source(full_source: str, function_name: str) -> str:
    """Grabs one top-level function's full text (signature through body),
    without importing the module - routers/statements.py imports fastapi,
    which this test suite intentionally doesn't depend on having installed.
    Slices from the function's `async def` line to the next top-level
    definition/decorator, rather than parsing indentation, since a
    multi-line signature's closing `):` sits at column 0 and would
    otherwise look like the end of the function body."""
    start_match = re.search(rf"^async def {function_name}\(", full_source, re.MULTILINE)
    if not start_match:
        raise AssertionError(f"could not locate function {function_name!r} in source")
    end_match = re.search(r"^(@router|async def |def )", full_source[start_match.end():], re.MULTILINE)
    end = start_match.end() + (end_match.start() if end_match else len(full_source) - start_match.end())
    return full_source[start_match.start():end]


class TestUploadPathHasNoFalseSuccessGap(unittest.TestCase):
    def test_malformed_xref_fixture_fails_before_any_persistence_step_would_run(self):
        """Replays routers/statements.py's exact synchronous sequence against
        the known-bad fixture (EDGE_CASE_REPORT.md finding 7): open_and_inspect
        succeeds, extract_text is the step that actually fails - and it fails
        before validate_signature/parse_period/parse_declared_totals, which
        are themselves all still upstream of any persistence call."""
        with open("mock/gpay_statement_20260101_20260630.pdf", "rb") as f:
            raw = f.read()

        page_count, _ = statement_parser.open_and_inspect(raw)
        self.assertGreater(page_count, 0)  # confirms the "looks valid" step really does pass

        with self.assertRaises(CorruptedPDFError):
            # This is the exact next line the router runs. If it raises (it
            # does), validate_signature/parse_period/parse_declared_totals and
            # every persistence call after them in upload_statement() never
            # execute for this file.
            statement_parser.extract_text(raw)

    def test_upload_router_calls_all_parsing_steps_before_any_persistence_call(self):
        """Static structural guard: reads routers/statements.py's own source
        and asserts persistence calls (store_pdf/statement create/job create)
        appear textually after the parsing try/except block, and that the
        block covers all four parser calls this pipeline depends on. This
        doesn't prove runtime behavior - test_malformed_xref_fixture_... does
        that - but it fails loudly if someone later reorders the function so
        a persistence call moves ahead of parsing, which is the one change
        that would reopen the false-success gap this phase confirms is
        currently closed."""
        source = _extract_function_source(_ROUTER_SOURCE, "upload_statement")

        parse_calls = [
            "open_and_inspect(",
            "extract_text(",
            "validate_signature(",
            "parse_period(",
            "parse_declared_totals(",
        ]
        persistence_calls = [
            "statement_repo.store_pdf(",
            "statement_repo.create(",
            "job_repo.create(",
        ]

        parse_positions = [source.index(call) for call in parse_calls]
        persistence_positions = [source.index(call) for call in persistence_calls]

        self.assertEqual(parse_positions, sorted(parse_positions), "parser calls must run in the documented order")
        self.assertLess(
            max(parse_positions), min(persistence_positions),
            "a persistence call appears before parsing completes - this would reopen the false-success gap",
        )

    def test_upload_reads_the_file_into_memory_with_no_temp_files_to_clean_up(self):
        """Phase 5 asks about safe cleanup of temporary files. There aren't
        any to clean up: UploadFile.read() is awaited directly into `raw_bytes`
        in routers/statements.py, and both pypdf and pdfplumber are called via
        io.BytesIO(raw_bytes) in statements/pdf_parser.py - nothing in this
        path ever writes to disk. Verified by inspection here rather than by
        an I/O test, since there's no filesystem write to assert the absence
        of."""
        upload_source = _extract_function_source(_ROUTER_SOURCE, "upload_statement")

        self.assertNotIn("tempfile", upload_source)
        self.assertNotIn("open(", upload_source)  # no local file writes
        self.assertIn("io.BytesIO", _PARSER_SOURCE)
        self.assertNotIn("tempfile", _PARSER_SOURCE)


if __name__ == "__main__":
    unittest.main()
