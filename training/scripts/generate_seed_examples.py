#!/usr/bin/env python3
"""Print a lightweight checklist for expanding the seed corpus.

This script deliberately does not synthesize examples by itself; model-generated
examples should be reviewed before landing in data/seed.
"""

from __future__ import annotations


CATEGORIES = {
    "completion.short": 60,
    "completion.long_obvious": 40,
    "edit.typo": 90,
    "edit.grammar": 70,
    "edit.phrase": 50,
    "edit.multi": 70,
    "edit.suffix_aware": 50,
    "noop.ambiguous": 80,
    "noop.unsafe": 70,
    "noop.overeager": 60,
}


def main() -> int:
    total = sum(CATEGORIES.values())
    print(f"Suggested first seed target: {total} reviewed examples")
    for category, count in CATEGORIES.items():
        print(f"- {category}: {count}")
    print("\nReview rules:")
    print("- Exactly one <|caret|> in input and target.")
    print("- No invented personal facts or commitments.")
    print("- Long completions only when the prior text strongly constrains the continuation.")
    print("- No-op examples should be common and intentional.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
