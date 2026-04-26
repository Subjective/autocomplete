#!/usr/bin/env python3
"""Score model predictions against TabAnywhere eval records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from dataset_utils import (
    CARET,
    changed_character_count,
    classify_rewrite,
    edit_count,
    has_prompt_delimiter_leak,
    read_jsonl,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("eval_dataset", type=Path)
    parser.add_argument("predictions", type=Path, help="JSONL with id and prediction fields")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    eval_records = {record["id"]: record for record in read_jsonl(args.eval_dataset)}
    prediction_records = read_jsonl(args.predictions)

    totals = {
        "records": 0,
        "parse_valid": 0,
        "kind_correct": 0,
        "exact_target": 0,
        "within_edit_count": 0,
        "within_changed_chars": 0,
        "must_not_contain_ok": 0,
    }
    failures: list[dict] = []

    for prediction_record in prediction_records:
        record_id = prediction_record.get("id")
        eval_record = eval_records.get(record_id)
        if eval_record is None:
            failures.append({"id": record_id, "reason": "unknown eval id"})
            continue

        prediction = prediction_record.get(
            "prediction",
            prediction_record.get("output", prediction_record.get("target", ""))
        )
        totals["records"] += 1

        parse_valid = prediction.count(CARET) == 1 and not has_prompt_delimiter_leak(prediction)
        totals["parse_valid"] += int(parse_valid)

        predicted_kind = classify_rewrite(eval_record["input"], prediction) if parse_valid else "invalid"
        kind_correct = predicted_kind == eval_record["expected_kind"]
        totals["kind_correct"] += int(kind_correct)
        totals["exact_target"] += int(prediction == eval_record["target"])

        within_edit_count = True
        if "max_edit_count" in eval_record:
            within_edit_count = edit_count(eval_record["input"], prediction) <= eval_record["max_edit_count"]
        totals["within_edit_count"] += int(within_edit_count)

        within_changed_chars = True
        if "max_changed_chars" in eval_record:
            within_changed_chars = changed_character_count(eval_record["input"], prediction) <= eval_record["max_changed_chars"]
        totals["within_changed_chars"] += int(within_changed_chars)

        forbidden = eval_record.get("must_not_contain", [])
        prediction_without_caret = prediction.replace(CARET, "")
        must_not_contain_ok = all(term.lower() not in prediction_without_caret.lower() for term in forbidden)
        totals["must_not_contain_ok"] += int(must_not_contain_ok)

        if not all([parse_valid, kind_correct, within_edit_count, within_changed_chars, must_not_contain_ok]):
            failures.append({
                "id": record_id,
                "expected_kind": eval_record["expected_kind"],
                "predicted_kind": predicted_kind,
                "parse_valid": parse_valid,
                "within_edit_count": within_edit_count,
                "within_changed_chars": within_changed_chars,
                "must_not_contain_ok": must_not_contain_ok,
            })

    if args.json:
        print(json.dumps({"totals": totals, "failures": failures}, indent=2, sort_keys=True))
    else:
        print(json.dumps(totals, indent=2, sort_keys=True))
        if failures:
            print("\nFailures:")
            for failure in failures:
                print(f"- {failure}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
