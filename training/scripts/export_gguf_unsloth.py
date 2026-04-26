#!/usr/bin/env python3
"""Export a merged TabAnywhere model to GGUF quantizations with Unsloth."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path("training/configs/export_gguf.yaml"))
    parser.add_argument(
        "--source-model",
        type=Path,
        default=None,
        help="Override source.merged_model_dir from the config.",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    source_model = args.source_model or Path(config["source"]["merged_model_dir"])

    from unsloth import FastLanguageModel

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=str(source_model),
        max_seq_length=2048,
        dtype=None,
        load_in_4bit=False,
    )

    for export in config["exports"]:
        output_path = Path(export["output_path"])
        output_path.parent.mkdir(parents=True, exist_ok=True)
        quantization = export["quantization"]
        output_dir = output_path.with_suffix("")
        output_dir.mkdir(parents=True, exist_ok=True)

        model.save_pretrained_gguf(
            str(output_dir),
            tokenizer,
            quantization_method=quantization,
        )
        print(f"Exported {quantization} GGUF under {output_dir}")
        print(f"Configured target path: {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
