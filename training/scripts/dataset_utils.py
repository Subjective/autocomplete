#!/usr/bin/env python3
"""Shared helpers for TabAnywhere training datasets."""

from __future__ import annotations

import difflib
import json
from pathlib import Path
from typing import Any, Iterable

CARET = "<|caret|>"
PROMPT_DELIMITERS = [
    "<|editable_text|>",
    "<|end_editable_text|>",
    "<|recent_actions|>",
    "<|end_recent_actions|>",
    "<|visual_context|>",
    "<|end_visual_context|>",
    "<|suggestion|>",
    "<|end_suggestion|>",
]


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                record = json.loads(stripped)
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {error}") from error
            record["_line_number"] = line_number
            records.append(record)
    return records


def write_jsonl(path: Path, records: Iterable[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            clean = {key: value for key, value in record.items() if not key.startswith("_")}
            handle.write(json.dumps(clean, ensure_ascii=False, sort_keys=True) + "\n")


def require_single_caret(value: str, label: str, errors: list[str]) -> None:
    if value.count(CARET) != 1:
        errors.append(f"{label} must contain exactly one {CARET} marker")


def has_prompt_delimiter_leak(value: str) -> bool:
    return any(delimiter in value for delimiter in PROMPT_DELIMITERS)


def strip_caret(value: str) -> tuple[str, int]:
    if value.count(CARET) != 1:
        return value.replace(CARET, ""), -1
    before, after = value.split(CARET)
    return before + after, len(before)


def classify_rewrite(input_text: str, output_text: str) -> str:
    original, original_caret = strip_caret(input_text)
    rewritten, _ = strip_caret(output_text)

    if original == rewritten:
        return "noop"

    before = original[:original_caret]
    after = original[original_caret:]
    if not after and rewritten.startswith(before):
        inserted = rewritten[len(before): len(rewritten) - len(after) if after else len(rewritten)]
        if inserted:
            return "completion"

    return "edit"


def changed_character_count(input_text: str, output_text: str) -> int:
    original, _ = strip_caret(input_text)
    rewritten, _ = strip_caret(output_text)
    matcher = difflib.SequenceMatcher(a=original, b=rewritten, autojunk=False)
    changed = 0
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != "equal":
            changed += (i2 - i1) + (j2 - j1)
    return changed


def edit_count(input_text: str, output_text: str) -> int:
    original, _ = strip_caret(input_text)
    rewritten, _ = strip_caret(output_text)
    matcher = difflib.SequenceMatcher(a=original, b=rewritten, autojunk=False)
    return sum(1 for tag, *_ in matcher.get_opcodes() if tag != "equal")


def render_user_prompt(record: dict[str, Any], template: str, candidate_count: int = 1) -> str:
    recent_actions = record.get("recent_actions") or ["None"]
    if isinstance(recent_actions, list):
        recent_actions_text = "\n".join(str(action) for action in recent_actions) or "None"
    else:
        recent_actions_text = str(recent_actions)

    replacements = {
        "{{app_name}}": record.get("app_name", "Unknown"),
        "{{window_title}}": record.get("window_title", "Unknown"),
        "{{field_role}}": record.get("field_role", "Unknown"),
        "{{candidate_count}}": str(candidate_count),
        "{{recent_actions}}": recent_actions_text,
        "{{visual_context}}": record.get("visual_context", "None") or "None",
        "{{input}}": record["input"],
    }

    rendered = template
    for placeholder, value in replacements.items():
        rendered = rendered.replace(placeholder, value)
    return rendered
