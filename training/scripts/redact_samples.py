#!/usr/bin/env python3
"""Redact common sensitive strings from local raw samples."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from dataset_utils import read_jsonl


PATTERNS = [
    (re.compile(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b"), "[EMAIL]"),
    (re.compile(r"\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}\b"), "[PHONE]"),
    (re.compile(r"\b(?:\d[ -]*?){13,19}\b"), "[CARD_NUMBER]"),
    (re.compile(r"\b\d{3}-\d{2}-\d{4}\b"), "[SSN]"),
    (re.compile(r"(?i)\b(api[_-]?key|token|password|secret)\s*[:=]\s*\S+"), r"\1=[REDACTED]"),
]


def redact_value(value: Any) -> Any:
    if isinstance(value, str):
        redacted = value
        for pattern, replacement in PATTERNS:
            redacted = pattern.sub(replacement, redacted)
        return redacted
    if isinstance(value, list):
        return [redact_value(item) for item in value]
    if isinstance(value, dict):
        return {key: redact_value(item) for key, item in value.items()}
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    records = read_jsonl(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        for record in records:
            clean = {key: value for key, value in record.items() if not key.startswith("_")}
            handle.write(json.dumps(redact_value(clean), ensure_ascii=False, sort_keys=True) + "\n")

    print(f"Redacted {len(records)} records to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
