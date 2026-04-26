#!/usr/bin/env python3
"""Convert local prompt-inspector exports into reviewed SFT candidates.

Expected input JSONL fields are intentionally simple:
- id
- input
- accepted_output or final_output
- app_name/window_title/field_role/category optional
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from dataset_utils import CARET, read_jsonl


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_jsonl", type=Path)
    parser.add_argument("output_jsonl", type=Path)
    parser.add_argument("--default-category", default="edit.multi")
    args = parser.parse_args()

    records = read_jsonl(args.raw_jsonl)
    converted = []
    skipped = 0

    for index, record in enumerate(records, start=1):
        target = record.get("accepted_output") or record.get("final_output")
        input_text = record.get("input")
        if not input_text or not target or input_text.count(CARET) != 1 or target.count(CARET) != 1:
            skipped += 1
            continue

        converted.append({
            "id": record.get("id", f"accepted-{index:04d}"),
            "category": record.get("category", args.default_category),
            "app_name": record.get("app_name", "Unknown"),
            "window_title": record.get("window_title", "Unknown"),
            "field_role": record.get("field_role", "Unknown"),
            "recent_actions": record.get("recent_actions", ["Accepted suggestion"]),
            "visual_context": record.get("visual_context", "None"),
            "input": input_text,
            "target": target,
            "notes": "Converted from local opt-in acceptance export; review before training.",
        })

    args.output_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with args.output_jsonl.open("w", encoding="utf-8") as handle:
        for record in converted:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")

    print(f"Converted {len(converted)} records to {args.output_jsonl}; skipped {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
