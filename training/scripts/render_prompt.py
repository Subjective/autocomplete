#!/usr/bin/env python3
"""Render a dataset record with the TabAnywhere prompt template."""

from __future__ import annotations

import argparse
from pathlib import Path

from dataset_utils import read_jsonl, render_user_prompt


DEFAULT_TEMPLATE = Path("training/prompts/edit_prediction_user_template.txt")
DEFAULT_SYSTEM = Path("training/prompts/edit_prediction_system.txt")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    parser.add_argument("--id", required=True)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--system", type=Path, default=DEFAULT_SYSTEM)
    parser.add_argument("--candidate-count", type=int, default=1)
    args = parser.parse_args()

    records = read_jsonl(args.dataset)
    record = next((item for item in records if item.get("id") == args.id), None)
    if record is None:
        raise SystemExit(f"No record with id {args.id}")

    template = args.template.read_text(encoding="utf-8")
    system = args.system.read_text(encoding="utf-8")
    user = render_user_prompt(record, template, candidate_count=args.candidate_count)

    print("=== SYSTEM ===")
    print(system.rstrip())
    print("\n=== USER ===")
    print(user.rstrip())
    print("\n=== TARGET ===")
    print(record.get("target", record.get("chosen", "")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
