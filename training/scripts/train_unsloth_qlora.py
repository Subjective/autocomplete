#!/usr/bin/env python3
"""Fine-tune Gemma for TabAnywhere edit prediction with Unsloth QLoRA.

This script is intended for a machine with a CUDA-capable GPU and the packages
listed in training/requirements-training.txt. It does not run inside the macOS
app; it produces LoRA/merged artifacts under training/models.
"""

from __future__ import annotations

import argparse
import inspect
import json
from pathlib import Path
from typing import Any

import yaml


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                records.append(json.loads(line))
    return records


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


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


def build_dataset_records(path: Path, system_prompt: str, user_template: str) -> list[dict[str, Any]]:
    records = []
    for record in read_jsonl(path):
        records.append({
            "id": record["id"],
            "category": record["category"],
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": render_user_prompt(record, user_template)},
                {"role": "assistant", "content": record["target"]},
            ],
        })
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path("training/configs/sft_gemma_lora.yaml"))
    parser.add_argument("--prepare-split", action="store_true", help="Train from source_seed_path if split files are absent.")
    parser.add_argument("--merge", action="store_true", help="Also save a merged 16-bit model after training.")
    args = parser.parse_args()

    config = load_config(args.config)

    from unsloth import FastLanguageModel
    from datasets import Dataset
    from transformers import TrainingArguments
    from trl import SFTTrainer

    prompt_config = config["prompt"]
    data_config = config["data"]
    lora_config = config["lora"]
    training_config = config["training"]
    output_config = config["output"]

    system_prompt = Path(prompt_config["system_path"]).read_text(encoding="utf-8")
    user_template = Path(prompt_config["user_template_path"]).read_text(encoding="utf-8")

    train_path = Path(data_config["train_path"])
    validation_path = Path(data_config["validation_path"])
    if args.prepare_split and not train_path.exists():
        raise SystemExit(
            "Split files are absent. Run training/scripts/split_dataset.py first; "
            "--prepare-split is reserved for future automatic splitting."
        )

    train_records = build_dataset_records(train_path, system_prompt, user_template)
    eval_records = build_dataset_records(validation_path, system_prompt, user_template) if validation_path.exists() else []

    max_sequence_length = int(data_config.get("max_sequence_length", 2048))
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=config["base_model"],
        max_seq_length=max_sequence_length,
        dtype=None,
        load_in_4bit=True,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=int(lora_config["r"]),
        target_modules=list(lora_config["target_modules"]),
        lora_alpha=int(lora_config["alpha"]),
        lora_dropout=float(lora_config["dropout"]),
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=int(training_config["seed"]),
    )

    def format_record(record: dict[str, Any]) -> dict[str, str]:
        text = tokenizer.apply_chat_template(
            record["messages"],
            tokenize=False,
            add_generation_prompt=False,
        )
        return {"text": text, "id": record["id"], "category": record["category"]}

    train_dataset = Dataset.from_list([format_record(record) for record in train_records])
    eval_dataset = Dataset.from_list([format_record(record) for record in eval_records]) if eval_records else None

    metrics_dir = Path(output_config["metrics_dir"])
    metrics_dir.mkdir(parents=True, exist_ok=True)

    evaluation_strategy_name = (
        "eval_strategy"
        if "eval_strategy" in inspect.signature(TrainingArguments).parameters
        else "evaluation_strategy"
    )
    training_args_kwargs = {
        "output_dir": str(metrics_dir),
        "per_device_train_batch_size": int(training_config["per_device_train_batch_size"]),
        "gradient_accumulation_steps": int(training_config["gradient_accumulation_steps"]),
        "learning_rate": float(training_config["learning_rate"]),
        "num_train_epochs": float(training_config["epochs"]),
        "weight_decay": float(training_config["weight_decay"]),
        "lr_scheduler_type": training_config["lr_scheduler_type"],
        "logging_steps": int(training_config["logging_steps"]),
        "save_steps": int(training_config["save_steps"]),
        "eval_steps": int(training_config["eval_steps"]),
        evaluation_strategy_name: "steps" if eval_dataset is not None else "no",
        "seed": int(training_config["seed"]),
        "report_to": "none",
    }
    if "warmup_steps" in training_config:
        training_args_kwargs["warmup_steps"] = int(training_config["warmup_steps"])
    else:
        training_args_kwargs["warmup_ratio"] = float(training_config["warmup_ratio"])
    training_args = TrainingArguments(**training_args_kwargs)

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        dataset_text_field="text",
        max_seq_length=max_sequence_length,
        packing=bool(training_config["packing"]),
        args=training_args,
    )
    trainer.train()

    adapter_dir = Path(output_config["adapter_dir"])
    adapter_dir.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(str(adapter_dir))
    tokenizer.save_pretrained(str(adapter_dir))
    print(f"Saved LoRA adapter to {adapter_dir}")

    if args.merge:
        merged_dir = Path(output_config["merged_dir"])
        merged_dir.mkdir(parents=True, exist_ok=True)
        model.save_pretrained_merged(str(merged_dir), tokenizer, save_method="merged_16bit")
        print(f"Saved merged model to {merged_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
