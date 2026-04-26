#!/usr/bin/env python3
"""Create deterministic train/validation splits from an SFT JSONL dataset."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from dataset_utils import read_jsonl, write_jsonl


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    parser.add_argument("--out-dir", type=Path, default=Path("training/runs/splits"))
    parser.add_argument("--validation-fraction", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    records = read_jsonl(args.dataset)
    rng = random.Random(args.seed)
    shuffled = list(records)
    rng.shuffle(shuffled)

    validation_count = max(1, round(len(shuffled) * args.validation_fraction)) if len(shuffled) > 1 else 0
    validation = shuffled[:validation_count]
    train = shuffled[validation_count:]

    args.out_dir.mkdir(parents=True, exist_ok=True)
    train_path = args.out_dir / "train.jsonl"
    validation_path = args.out_dir / "validation.jsonl"
    write_jsonl(train_path, train)
    write_jsonl(validation_path, validation)

    print(f"Wrote {len(train)} train records to {train_path}")
    print(f"Wrote {len(validation)} validation records to {validation_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
