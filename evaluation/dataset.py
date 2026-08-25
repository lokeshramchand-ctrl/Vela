"""
Wave 8: Synthetic ground-truth dataset for matching-engine evaluation.

Generates two ledgers (source A, source B) that mimic reconciling two
independent records of the same underlying transactions (e.g. an internal
ledger vs. a bank statement) with realistic noise: merchant-name spelling
drift, small amount deltas (fees/FX rounding), and date skew (settlement lag).

Ground truth is tracked per source-A record and falls into exactly three
buckets, matching the Track 04 evaluation brief:

  TRUE_MATCH (221):  A record has exactly one correct partner in source B.
  KNOWN_EXCEPTION (21): A record has no true partner in source B, but is
      deliberately confusable with an unrelated B record (similar amount/date,
      sometimes similar name) — a classic "looks like a match but isn't" trap.
  AMBIGUOUS (8): A record has two plausible B candidates that are nearly
      indistinguishable by the matcher's own signals — there is no single
      defensible answer, so the correct system behavior is to decline to
      pick one, not to guess.

Source B has 250 records total: 221 true partners (one per TRUE_MATCH case)
plus 29 unmatched filler records (extra bank-side entries with no internal
counterpart — also a realistic reconciliation artifact). The 21
KNOWN_EXCEPTION and 8 AMBIGUOUS cases point at B records reused from that
same pool, since a real decoy is, by definition, someone else's real
transaction that merely looks similar.
"""

import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum

TRUE_MATCH_COUNT = 221
KNOWN_EXCEPTION_COUNT = 21
AMBIGUOUS_COUNT = 8
TOTAL_A_RECORDS = TRUE_MATCH_COUNT + KNOWN_EXCEPTION_COUNT + AMBIGUOUS_COUNT  # 250
TOTAL_B_RECORDS = 250
FILLER_B_COUNT = TOTAL_B_RECORDS - TRUE_MATCH_COUNT  # 29

DEFAULT_SEED = 42

# Canonical entities: (canonical name, [noisy surface-form variants])
CANONICAL_ENTITIES = [
    ("Swiggy", ["SWIGGY", "SWIGGY*ORDER", "BUNDL TECHNOLOGIES", "SWIGGY INSTAMART"]),
    ("Zomato", ["ZOMATO", "ZOMATO ONLINE", "ZOMATO LTD"]),
    ("Uber", ["UBER", "UBER *TRIP", "UBER INDIA", "UBER EATS"]),
    ("Ola", ["OLA", "OLA CABS", "ANI TECHNOLOGIES"]),
    ("Netflix", ["NETFLIX", "NETFLIX.COM", "NETFLIX SUBSCRIPTION"]),
    ("Spotify", ["SPOTIFY", "SPOTIFY AB", "SPOTIFY PREMIUM"]),
    ("Amazon", ["AMAZON", "AMAZON.IN", "AMZN", "AMAZON PAY"]),
    ("Starbucks", ["STARBUCKS", "STARBUCKS COFFEE", "TATA STARBUCKS"]),
    ("Blinkit", ["BLINKIT", "BLINK COMMERCE", "GROFERS"]),
    ("BookMyShow", ["BOOKMYSHOW", "BIG TREE ENTERTAINMENT"]),
    ("YouTube", ["YOUTUBE", "YOUTUBE PREMIUM", "GOOGLE YOUTUBE"]),
    ("IKEA", ["IKEA", "IKEA INDIA"]),
    ("Apollo Pharmacy", ["APOLLO PHARMACY", "APOLLO HEALTHCO"]),
    ("Decathlon", ["DECATHLON", "DECATHLON SPORTS"]),
    ("APSRTC", ["APSRTC", "AP STATE ROAD TRANSPORT"]),
    ("Karachi Bakery", ["KARACHI BAKERY", "KARACHI BACKERY"]),
    ("Cream Stone", ["CREAM STONE", "CREAMSTONE"]),
    ("PhonePe", ["PHONEPE", "PHONEPE WALLET"]),
    ("Google Pay", ["GPAY", "GOOGLE PAY", "GOOGLE PAY INDIA"]),
    ("Airtel", ["AIRTEL", "BHARTI AIRTEL", "AIRTEL PREPAID"]),
    ("Jio", ["JIO", "RELIANCE JIO", "JIO RECHARGE"]),
    ("BigBasket", ["BIGBASKET", "BIG BASKET", "SUPERMARKET GROCERY"]),
    ("Myntra", ["MYNTRA", "MYNTRA DESIGNS"]),
    ("Flipkart", ["FLIPKART", "FLIPKART INTERNET"]),
    ("Paytm", ["PAYTM", "ONE97 COMMUNICATIONS"]),
    ("Dominos", ["DOMINOS", "DOMINOS PIZZA", "JUBILANT FOODWORKS"]),
    ("McDonalds", ["MCDONALDS", "MCDONALD'S INDIA"]),
    ("Café Coffee Day", ["CAFE COFFEE DAY", "CCD", "COFFEE DAY"]),
    ("Lenskart", ["LENSKART", "LENSKART SOLUTIONS"]),
    ("Nykaa", ["NYKAA", "FSN E-COMMERCE"]),
]


class CaseCategory(str, Enum):
    TRUE_MATCH = "true_match"
    KNOWN_EXCEPTION = "known_exception"
    AMBIGUOUS = "ambiguous"


@dataclass
class LedgerRecord:
    """A single transaction record on one side of the reconciliation."""
    id: str
    source: str  # "A" or "B"
    text: str  # noisy merchant text as it appears on the statement
    canonical_entity: str  # ground-truth entity identity (not visible to the matcher)
    amount: float
    date: datetime
    historical_encounters: int = 0  # how many times this merchant has been seen before
    trust_state: str | None = None  # EPHEMERAL / TEMPORARY / PERMANENT

    def as_dict(self) -> dict:
        return {
            "id": self.id,
            "source": self.source,
            "text": self.text,
            "amount": self.amount,
            "date": self.date.isoformat(),
        }


@dataclass
class GroundTruthCase:
    """Ground truth + candidate set for a single source-A record."""
    a_id: str
    category: CaseCategory
    true_b_id: str | None  # the correct partner, or None if no correct answer exists
    candidate_b_ids: list[str] = field(default_factory=list)  # B records to score against


@dataclass
class EvaluationDataset:
    source_a: list[LedgerRecord]
    source_b: list[LedgerRecord]
    cases: list[GroundTruthCase]

    def b_by_id(self) -> dict[str, LedgerRecord]:
        return {r.id: r for r in self.source_b}

    def a_by_id(self) -> dict[str, LedgerRecord]:
        return {r.id: r for r in self.source_a}


def _random_date(rng: random.Random, base: datetime) -> datetime:
    return base + timedelta(days=rng.randint(0, 400))


def _skew_date(rng: random.Random, base_date: datetime, max_days: int) -> datetime:
    return base_date + timedelta(days=rng.randint(0, max_days))


def _skew_amount(rng: random.Random, base_amount: float, pct: float) -> float:
    delta = base_amount * pct * rng.uniform(-1, 1)
    return round(base_amount + delta, 2)


def generate_dataset(seed: int = DEFAULT_SEED) -> EvaluationDataset:
    """Generate the Wave 8 synthetic ground-truth dataset.

    Deterministic given `seed`: reruns produce the identical dataset so
    evaluation results are reproducible.
    """
    rng = random.Random(seed)
    base_date = datetime(2026, 1, 1)

    source_a: list[LedgerRecord] = []
    source_b: list[LedgerRecord] = []
    cases: list[GroundTruthCase] = []

    # Assign each A record a scenario slot up front, then shuffle so
    # categories aren't clustered by id order.
    categories = (
        [CaseCategory.TRUE_MATCH] * TRUE_MATCH_COUNT
        + [CaseCategory.KNOWN_EXCEPTION] * KNOWN_EXCEPTION_COUNT
        + [CaseCategory.AMBIGUOUS] * AMBIGUOUS_COUNT
    )
    rng.shuffle(categories)

    # --- Step 1: build all TRUE_MATCH pairs (A record + its dedicated B partner) ---
    # Half are "clean" (well-known recurring merchant, exact amount, same-day
    # settlement) and half are "noisy" (less-familiar merchant, small fee/FX
    # drift, settlement lag) - a realistic mix that spreads true matches across
    # both the AUTO_MATCH and HUMAN_REVIEW tiers instead of landing them all
    # in one bucket.
    true_match_b_ids: list[str] = []
    a_index = 0
    for category in categories:
        if category != CaseCategory.TRUE_MATCH:
            continue
        entity_name, variants = rng.choice(CANONICAL_ENTITIES)
        a_id = f"A{a_index:04d}"
        b_id = f"B{a_index:04d}"

        canonical_amount = round(rng.uniform(50, 5000), 2)
        canonical_date = _random_date(rng, base_date)

        is_clean = rng.random() < 0.55
        if is_clean:
            encounters = rng.randint(15, 40)
            amount_pct, date_skew = 0.0, 0
        else:
            encounters = rng.randint(0, 10)
            amount_pct, date_skew = 0.03, 2
        trust_state = (
            "PERMANENT" if encounters > 20 else "TEMPORARY" if encounters > 5 else "EPHEMERAL"
        )

        a_record = LedgerRecord(
            id=a_id,
            source="A",
            text=rng.choice(variants),
            canonical_entity=entity_name,
            amount=canonical_amount,
            date=canonical_date,
            historical_encounters=encounters,
            trust_state=trust_state,
        )
        # B-side partner: same entity, small noise (fees/FX rounding, settlement lag).
        b_record = LedgerRecord(
            id=b_id,
            source="B",
            text=rng.choice(variants),
            canonical_entity=entity_name,
            amount=_skew_amount(rng, canonical_amount, pct=amount_pct),
            date=_skew_date(rng, canonical_date, max_days=date_skew),
        )
        source_a.append(a_record)
        source_b.append(b_record)
        true_match_b_ids.append(b_id)
        cases.append(GroundTruthCase(
            a_id=a_id, category=category, true_b_id=b_id, candidate_b_ids=[b_id],
        ))
        a_index += 1

    # --- Step 2: pad source B with unmatched filler records (no true partner in A) ---
    filler_b_ids: list[str] = []
    for i in range(FILLER_B_COUNT):
        entity_name, variants = rng.choice(CANONICAL_ENTITIES)
        b_id = f"BF{i:04d}"
        source_b.append(LedgerRecord(
            id=b_id,
            source="B",
            text=rng.choice(variants),
            canonical_entity=entity_name,
            amount=round(rng.uniform(50, 5000), 2),
            date=_random_date(rng, base_date),
        ))
        filler_b_ids.append(b_id)

    decoy_pool = true_match_b_ids + filler_b_ids  # any existing B record can be a decoy

    # --- Step 2b: give each TRUE_MATCH case real competition. Without other
    # candidates, "finding" the one and only record scored is trivial and
    # proves nothing about ranking or false-match risk. Add two unrelated
    # distractors from the wider B pool so the matcher must actually
    # out-rank them for the true partner to win. ---
    for case in cases:
        distractor_pool = [b_id for b_id in decoy_pool if b_id != case.true_b_id]
        case.candidate_b_ids.extend(rng.sample(distractor_pool, 2))

    # --- Step 3: KNOWN_EXCEPTION — A record with no true partner, paired against a
    # confusable, unrelated B record (close amount + close date, different entity). ---
    for category in categories:
        if category != CaseCategory.KNOWN_EXCEPTION:
            continue
        decoy_id = rng.choice(decoy_pool)
        decoy = next(r for r in source_b if r.id == decoy_id)

        # Pick a *different* entity so this is a genuine non-match, but mirror the
        # decoy's amount/date closely enough to be tempting.
        other_entities = [e for e in CANONICAL_ENTITIES if e[0] != decoy.canonical_entity]
        entity_name, variants = rng.choice(other_entities)
        a_id = f"A{a_index:04d}"

        source_a.append(LedgerRecord(
            id=a_id,
            source="A",
            text=rng.choice(variants),
            canonical_entity=entity_name,
            amount=_skew_amount(rng, decoy.amount, pct=0.02),
            date=_skew_date(rng, decoy.date, max_days=1),
        ))
        cases.append(GroundTruthCase(
            a_id=a_id, category=category, true_b_id=None, candidate_b_ids=[decoy_id],
        ))
        a_index += 1

    # --- Step 4: AMBIGUOUS — A record with two near-tied plausible B candidates. ---
    for category in categories:
        if category != CaseCategory.AMBIGUOUS:
            continue
        pair = rng.sample(true_match_b_ids, 2)
        b1 = next(r for r in source_b if r.id == pair[0])
        b2 = next(r for r in source_b if r.id == pair[1])

        # Synthesize an A record that is torn between the two candidates: its
        # merchant text matches b1 well while its amount matches b2 well (and
        # the date sits between both), so name and amount signals disagree and
        # no single candidate cleanly wins — a genuine, irreducible tie.
        variants_for_b1 = next(v for name, v in CANONICAL_ENTITIES if name == b1.canonical_entity)
        a_id = f"A{a_index:04d}"
        blended_date = b1.date + (b2.date - b1.date) / 2

        source_a.append(LedgerRecord(
            id=a_id,
            source="A",
            text=rng.choice(variants_for_b1),
            canonical_entity=b1.canonical_entity,
            amount=b2.amount,
            date=blended_date,
        ))
        cases.append(GroundTruthCase(
            a_id=a_id, category=category, true_b_id=None, candidate_b_ids=list(pair),
        ))
        a_index += 1

    rng.shuffle(source_a)
    rng.shuffle(source_b)

    return EvaluationDataset(source_a=source_a, source_b=source_b, cases=cases)
