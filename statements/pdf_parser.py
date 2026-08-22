import io
import logging
import re
from datetime import UTC, date, datetime, timedelta, timezone

import pdfplumber
import pypdf

logger = logging.getLogger(__name__)

# Google Pay (India) statements report local times with no explicit UTC
# offset - the phone number / ₹ currency / HDFC-style bank naming are all
# India-locale signals, so IST is assumed and converted to UTC for storage
# (every other timestamp in this app is UTC-aware, see models/schemas.py).
IST = timezone(timedelta(hours=5, minutes=30))


class CorruptedPDFError(Exception):
    """The uploaded file isn't a readable PDF at all (truncated, wrong file type, etc.)."""


class PasswordRequiredError(Exception):
    """The PDF is encrypted and no password was supplied."""


class IncorrectPasswordError(Exception):
    """The supplied password failed to decrypt the PDF."""


class UnsupportedStatementError(Exception):
    """The file is a valid, readable PDF but doesn't match the known Google Pay statement layout."""


# Validated directly against a real Google Pay statement (mock/gpay_statement_20260101_20260630.pdf,
# 19 pages / 184 transactions): every record extracts as exactly 3 lines at
# pdfplumber's default y-tolerance, once x_tolerance is narrowed from the
# default 3 (which collapses inter-word spacing on this font entirely - see
# extract_text() below) to 1:
#   01 Jan, 2026 Paid to Toni and Guy ₹252
#   04:47 PM UPI Transaction ID: 116512346960
#   Paid by HDFC Bank 5488
# Parsing the full real sample this way and summing DEBIT/CREDIT amounts
# reconciles exactly against the statement's own declared Sent/Received
# totals (₹80,634.04 / ₹28,975).
_RECORD_RE = re.compile(
    r"(?P<date>\d{2} \w{3}, \d{4}) (?P<direction>Paid to|Received from) (?P<counterparty>.+?) ₹(?P<amount>[\d,]+\.?\d*)\n"
    r"(?P<time>\d{1,2}:\d{2} [AP]M) UPI Transaction ID: (?P<ref>\d+)\n"
    r"(?:Paid by|Paid to) (?P<bank_line>.+)"
)
_PERIOD_RE = re.compile(r"(\d{2} \w+ \d{4})\s*-\s*(\d{2} \w+ \d{4})")
_TOTALS_RE = re.compile(r"₹([\d,]+\.?\d*)\s*₹([\d,]+\.?\d*)")
_BANK_LINE_RE = re.compile(r"^(?P<bank>.*\D)\s*(?P<last4>\d{2,6})$")

# The literal wordmark "Google Pay" never appears in the extracted text layer
# as a page title (it's a logo image) - it only shows up inside the repeated
# disclaimer paragraph ("...payments made by you on the Google Pay app...").
# All three of these must be present for a document to be accepted.
REQUIRED_SIGNATURE_STRINGS = ("Transaction statement", "Google Pay", "UPI Transaction ID:")


class ParsedTransaction:
    """Internal parsing artifact - never serialized directly in an API
    response. statements/statement_service.py converts these into
    models.schemas.Transaction documents after categorization."""

    __slots__ = ("timestamp", "direction", "counterparty_raw", "amount", "reference_number", "bank", "account_last4")

    def __init__(self, timestamp, direction, counterparty_raw, amount, reference_number, bank, account_last4):
        self.timestamp = timestamp
        self.direction = direction
        self.counterparty_raw = counterparty_raw
        self.amount = amount
        self.reference_number = reference_number
        self.bank = bank
        self.account_last4 = account_last4


class GooglePayStatementParser:
    def open_and_inspect(self, raw_bytes: bytes, password: str | None = None) -> tuple[int, dict[str, str]]:
        """Validates the file is a readable PDF and handles encryption.
        Returns (page_count, best-effort metadata dict). Raises
        CorruptedPDFError, PasswordRequiredError, or IncorrectPasswordError.
        """
        try:
            reader = pypdf.PdfReader(io.BytesIO(raw_bytes))
            if reader.is_encrypted:
                if password is None:
                    raise PasswordRequiredError(
                        "This PDF is password-protected. Provide the password to continue."
                    )
                if reader.decrypt(password) == pypdf.PasswordType.NOT_DECRYPTED:
                    raise IncorrectPasswordError("The provided password is incorrect.")

            page_count = len(reader.pages)
            if page_count == 0:
                raise CorruptedPDFError("The uploaded PDF has no pages.")

            raw_metadata = reader.metadata or {}
            metadata = {str(k).lstrip("/"): str(v) for k, v in raw_metadata.items() if v is not None}
        except (PasswordRequiredError, IncorrectPasswordError):
            raise
        except Exception as e:
            logger.warning("Failed to open uploaded PDF.", exc_info=True)
            raise CorruptedPDFError("The uploaded file is not a valid PDF.") from e

        return page_count, metadata

    def extract_text(self, raw_bytes: bytes, password: str | None = None) -> str:
        """pdfplumber's default word x_tolerance (3) collapses inter-word
        spacing on this statement's font entirely - confirmed against the
        real sample: "Paid to Toni and Guy" extracts as "PaidtoToniandGuy" at
        the default tolerance. Narrowing to 1 recovers correct spacing."""
        try:
            with pdfplumber.open(io.BytesIO(raw_bytes), password=password or "") as pdf:
                return "\n".join(page.extract_text(x_tolerance=1) or "" for page in pdf.pages)
        except Exception as e:
            logger.warning("Failed to extract text from uploaded PDF.", exc_info=True)
            raise CorruptedPDFError("Failed to extract text from the uploaded PDF.") from e

    def validate_signature(self, full_text: str) -> None:
        if any(marker not in full_text for marker in REQUIRED_SIGNATURE_STRINGS):
            raise UnsupportedStatementError("This does not appear to be a supported Google Pay statement.")

    def parse_period(self, full_text: str) -> tuple[date, date]:
        match = _PERIOD_RE.search(full_text)
        if not match:
            raise UnsupportedStatementError("Could not locate the statement period in this document.")
        start = datetime.strptime(match.group(1), "%d %B %Y").date()
        end = datetime.strptime(match.group(2), "%d %B %Y").date()
        return start, end

    def parse_declared_totals(self, full_text: str) -> tuple[float | None, float | None]:
        """Best-effort: the page-1 Sent/Received header. Absence isn't fatal -
        reconciliation just can't be checked for this statement."""
        match = _TOTALS_RE.search(full_text)
        if not match:
            return None, None
        return self._parse_amount(match.group(1)), self._parse_amount(match.group(2))

    def parse_transactions(self, full_text: str) -> list[ParsedTransaction]:
        parsed = []
        for match in _RECORD_RE.finditer(full_text):
            bank, last4 = self._parse_bank_line(match.group("bank_line"))
            parsed.append(
                ParsedTransaction(
                    timestamp=self._parse_timestamp(match.group("date"), match.group("time")),
                    direction=match.group("direction"),
                    counterparty_raw=" ".join(match.group("counterparty").split()),
                    amount=self._parse_amount(match.group("amount")),
                    reference_number=match.group("ref"),
                    bank=bank,
                    account_last4=last4,
                )
            )
        return parsed

    @staticmethod
    def _parse_amount(raw: str) -> float:
        return float(raw.replace(",", ""))

    @staticmethod
    def _parse_timestamp(date_str: str, time_str: str) -> datetime:
        naive = datetime.strptime(f"{date_str} {time_str}", "%d %b, %Y %I:%M %p")
        return naive.replace(tzinfo=IST).astimezone(UTC)

    @staticmethod
    def _parse_bank_line(bank_line: str) -> tuple[str, str | None]:
        match = _BANK_LINE_RE.match(bank_line.strip())
        if not match:
            return bank_line.strip(), None
        return match.group("bank").strip(), match.group("last4")


statement_parser = GooglePayStatementParser()
