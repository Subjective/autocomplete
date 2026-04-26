#!/usr/bin/env python3
"""Validate TabAnywhere training/eval/preference JSONL files."""

from __future__ import annotations

import argparse
from pathlib import Path

from dataset_utils import (
    CARET,
    changed_character_count,
    classify_rewrite,
    edit_count,
    has_prompt_delimiter_leak,
    read_jsonl,
    require_single_caret,
)


REQUIRED_FIELDS = {
    "sft": ["id", "category", "input", "target"],
    "eval": ["id", "category", "expected_kind", "input", "target"],
    "preference": ["id", "category", "input", "chosen", "rejected"],
}


def validate_record(record: dict, kind: str) -> list[str]:
    errors: list[str] = []
    prefix = f"{record.get('id', '<missing-id>')} line {record.get('_line_number', '?')}"

    for field in REQUIRED_FIELDS[kind]:
        if field not in record:
            errors.append(f"{prefix}: missing required field {field}")

    if errors:
        return errors

    if kind in {"sft", "eval"}:
        require_single_caret(record["input"], f"{prefix}: input", errors)
        require_single_caret(record["target"], f"{prefix}: target", errors)
        if has_prompt_delimiter_leak(record["target"]):
            errors.append(f"{prefix}: target leaks prompt delimiters")

        if kind == "eval":
            predicted_kind = classify_rewrite(record["input"], record["target"])
            if predicted_kind != record["expected_kind"]:
                errors.append(
                    f"{prefix}: target classifies as {predicted_kind}, expected {record['expected_kind']}"
                )
            if "max_edit_count" in record and edit_count(record["input"], record["target"]) > record["max_edit_count"]:
                errors.append(f"{prefix}: target exceeds max_edit_count")
            if "max_changed_chars" in record and changed_character_count(record["input"], record["target"]) > record["max_changed_chars"]:
                errors.append(f"{prefix}: target exceeds max_changed_chars")

    if kind == "preference":
        for field in ["input", "chosen", "rejected"]:
            require_single_caret(record[field], f"{prefix}: {field}", errors)
        if record["chosen"] == record["rejected"]:
            errors.append(f"{prefix}: chosen and rejected must differ")
        if classify_rewrite(record["input"], record["chosen"]) == "noop" and "noop" not in record["category"]:
            errors.append(f"{prefix}: chosen is noop for non-noop category")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--kind", choices=sorted(REQUIRED_FIELDS), required=True)
    args = parser.parse_args()

    records = read_jsonl(args.path)
    errors: list[str] = []
    seen_ids: set[str] = set()

    for record in records:
        record_id = record.get("id")
        if record_id in seen_ids:
            errors.append(f"{record_id}: duplicate id")
        seen_ids.add(record_id)
        errors.extend(validate_record(record, args.kind))

    if errors:
        print(f"Validation failed for {args.path} ({len(errors)} error{'s' if len(errors) != 1 else ''})")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Validated {len(records)} {args.kind} records from {args.path}")
    print(f"All records contain exactly one {CARET} marker in required rewrite fields.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
