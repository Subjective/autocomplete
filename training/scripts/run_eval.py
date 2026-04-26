#!/usr/bin/env python3
"""Render eval prompts for an external model runner.

This script does not call a model directly. It creates JSONL prompts that can be
fed to llama.cpp, a notebook, or a hosted batch runner. Score the model outputs
with score_predictions.py.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from dataset_utils import read_jsonl, render_user_prompt


DEFAULT_TEMPLATE = Path("training/prompts/edit_prediction_user_template.txt")
DEFAULT_SYSTEM = Path("training/prompts/edit_prediction_system.txt")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("eval_dataset", type=Path)
    parser.add_argument("--output", type=Path, default=Path("training/runs/eval_prompts.jsonl"))
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--system", type=Path, default=DEFAULT_SYSTEM)
    args = parser.parse_args()

    records = read_jsonl(args.eval_dataset)
    template = args.template.read_text(encoding="utf-8")
    system = args.system.read_text(encoding="utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", encoding="utf-8") as handle:
        for record in records:
            rendered = {
                "id": record["id"],
                "system": system,
                "user": render_user_prompt(record, template),
                "target": record["target"],
                "expected_kind": record["expected_kind"],
            }
            handle.write(json.dumps(rendered, ensure_ascii=False, sort_keys=True) + "\n")

    print(f"Wrote {len(records)} eval prompts to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
