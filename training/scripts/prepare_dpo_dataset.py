#!/usr/bin/env python3
"""Render TabAnywhere preference JSONL into DPO prompt/chosen/rejected records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from dataset_utils import read_jsonl, render_user_prompt


DEFAULT_SYSTEM = Path("training/prompts/edit_prediction_system.txt")
DEFAULT_TEMPLATE = Path("training/prompts/edit_prediction_user_template.txt")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_jsonl", type=Path)
    parser.add_argument("output_jsonl", type=Path)
    parser.add_argument("--system", type=Path, default=DEFAULT_SYSTEM)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--candidate-count", type=int, default=1)
    args = parser.parse_args()

    system = args.system.read_text(encoding="utf-8")
    template = args.template.read_text(encoding="utf-8")
    records = read_jsonl(args.input_jsonl)

    args.output_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with args.output_jsonl.open("w", encoding="utf-8") as handle:
        for record in records:
            prompt = [
                {"role": "system", "content": system},
                {
                    "role": "user",
                    "content": render_user_prompt(
                        record,
                        template,
                        candidate_count=args.candidate_count,
                    ),
                },
            ]
            output = {
                "id": record["id"],
                "category": record["category"],
                "prompt": prompt,
                "chosen": [{"role": "assistant", "content": record["chosen"]}],
                "rejected": [{"role": "assistant", "content": record["rejected"]}],
            }
            handle.write(json.dumps(output, ensure_ascii=False, sort_keys=True) + "\n")

    print(f"Wrote {len(records)} DPO preference records to {args.output_jsonl}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
