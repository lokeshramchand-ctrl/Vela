"""Pitch-video / demo helper: pulls one AUTO_MATCH, one HUMAN_REVIEW, and one
EXCEPTION case straight out of the real Track 04 benchmark and prints them
readably, so the confidence wall's three-way routing can be shown live
instead of narrated.

Usage: python -m evaluation.demo_three_cases
"""

from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall
from evaluation.dataset import generate_track04_benchmark
from evaluation.harness import _score_candidates


def main() -> None:
    dataset = generate_track04_benchmark()
    matcher = AIEntityMatcher()
    a_by_id = dataset.a_by_id()
    b_by_id = dataset.b_by_id()

    wanted: dict[ConfidenceWall, tuple | None] = {
        ConfidenceWall.AUTO_MATCH: None,
        ConfidenceWall.HUMAN_REVIEW: None,
        ConfidenceWall.EXCEPTION: None,
    }

    for case in dataset.cases:
        a_record = a_by_id[case.a_id]
        candidates = [b_by_id[b_id] for b_id in case.candidate_b_ids]
        ranked = _score_candidates(matcher, a_record, candidates)
        top = matcher.propose_decision(ranked)
        if not top or wanted.get(top.confidence_wall) is not None:
            continue
        wanted[top.confidence_wall] = (a_record, top)

    for decision, payload in wanted.items():
        print(f"\n=== {decision} ===")
        if payload is None:
            print("(no example found in this benchmark run)")
            continue

        a_record, top = payload
        print(f"Source A record: {a_record.text!r}  amount={a_record.amount}  direction={a_record.direction}")

        b_id = top.evidence.get("b_id")
        if b_id:
            b_record = b_by_id[b_id]
            print(f"Matched to B:    {b_record.text!r}  amount={b_record.amount}  direction={b_record.direction}")

        print(f"Confidence:      {top.confidence:.3f}")
        print(f"Exception reason:{top.exception_reason}")


if __name__ == "__main__":
    main()
