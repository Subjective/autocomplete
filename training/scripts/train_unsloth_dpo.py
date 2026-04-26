#!/usr/bin/env python3
"""Preference-tune TabAnywhere edit prediction with Unsloth DPO.

Run this after the SFT stage. The script loads the SFT LoRA adapter when it is
available, renders preference pairs with the same prompt contract used by the
app, then trains a small DPO adapter focused on restraint and groundedness.
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


def filter_supported_kwargs(target: Any, kwargs: dict[str, Any]) -> dict[str, Any]:
    signature = inspect.signature(target)
    if any(parameter.kind == inspect.Parameter.VAR_KEYWORD for parameter in signature.parameters.values()):
        return kwargs
    return {key: value for key, value in kwargs.items() if key in signature.parameters}


def strategy_argument_name(training_args_cls: Any) -> str:
    parameters = inspect.signature(training_args_cls).parameters
    return "eval_strategy" if "eval_strategy" in parameters else "evaluation_strategy"


def build_preference_records(
    path: Path,
    system_prompt: str,
    user_template: str,
    tokenizer: Any,
) -> list[dict[str, Any]]:
    records = []
    eos_token = tokenizer.eos_token or ""
    for record in read_jsonl(path):
        prompt_messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": render_user_prompt(record, user_template)},
        ]
        prompt = tokenizer.apply_chat_template(
            prompt_messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        chosen = record["chosen"]
        rejected = record["rejected"]
        if eos_token:
            chosen = chosen if chosen.endswith(eos_token) else chosen + eos_token
            rejected = rejected if rejected.endswith(eos_token) else rejected + eos_token

        records.append({
            "id": record["id"],
            "category": record["category"],
            "prompt": prompt,
            "chosen": chosen,
            "rejected": rejected,
        })
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path("training/configs/dpo_gemma_lora.yaml"))
    parser.add_argument("--merge", action="store_true", help="Also save a merged 16-bit model after DPO.")
    parser.add_argument(
        "--allow-base",
        action="store_true",
        help="Allow DPO directly from the base model if the SFT adapter is absent.",
    )
    args = parser.parse_args()

    config = load_config(args.config)

    from unsloth import FastLanguageModel
    from datasets import Dataset
    from trl import DPOConfig, DPOTrainer

    prompt_config = config["prompt"]
    data_config = config["data"]
    lora_config = config["lora"]
    training_config = config["training"]
    output_config = config["output"]

    system_prompt = Path(prompt_config["system_path"]).read_text(encoding="utf-8")
    user_template = Path(prompt_config["user_template_path"]).read_text(encoding="utf-8")

    adapter_dir = Path(config.get("sft_adapter_dir", ""))
    if not adapter_dir.exists() and not args.allow_base:
        raise SystemExit(
            f"SFT adapter not found at {adapter_dir}. Run SFT first or pass --allow-base to DPO from the base model."
        )

    model_name = str(adapter_dir) if adapter_dir.exists() else config["base_model"]
    max_sequence_length = int(data_config.get("max_sequence_length", 1024))

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,
        max_seq_length=max_sequence_length,
        dtype=None,
        load_in_4bit=True,
    )

    if not adapter_dir.exists():
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

    train_path = Path(data_config["train_path"])
    validation_path = Path(data_config["validation_path"])
    train_records = build_preference_records(train_path, system_prompt, user_template, tokenizer)
    eval_records = (
        build_preference_records(validation_path, system_prompt, user_template, tokenizer)
        if validation_path.exists()
        else []
    )
    train_dataset = Dataset.from_list(train_records)
    eval_dataset = Dataset.from_list(eval_records) if eval_records else None

    metrics_dir = Path(output_config["metrics_dir"])
    metrics_dir.mkdir(parents=True, exist_ok=True)

    dpo_args_kwargs = {
        "output_dir": str(metrics_dir),
        "per_device_train_batch_size": int(training_config["per_device_train_batch_size"]),
        "gradient_accumulation_steps": int(training_config["gradient_accumulation_steps"]),
        "learning_rate": float(training_config["learning_rate"]),
        "warmup_steps": int(training_config.get("warmup_steps", 0)),
        "num_train_epochs": float(training_config["epochs"]),
        "weight_decay": float(training_config["weight_decay"]),
        "lr_scheduler_type": training_config["lr_scheduler_type"],
        "logging_steps": int(training_config["logging_steps"]),
        "save_steps": int(training_config["save_steps"]),
        "eval_steps": int(training_config["eval_steps"]),
        strategy_argument_name(DPOConfig): "steps" if eval_dataset is not None else "no",
        "seed": int(training_config["seed"]),
        "report_to": "none",
        "beta": float(training_config["beta"]),
        "loss_type": training_config["loss_type"],
        "max_length": int(data_config["max_sequence_length"]),
        "max_prompt_length": int(data_config["max_prompt_length"]),
    }
    dpo_args = DPOConfig(**filter_supported_kwargs(DPOConfig, dpo_args_kwargs))

    trainer_kwargs = {
        "model": model,
        "ref_model": None,
        "args": dpo_args,
        "train_dataset": train_dataset,
        "eval_dataset": eval_dataset,
    }
    trainer_parameters = inspect.signature(DPOTrainer).parameters
    if "processing_class" in trainer_parameters:
        trainer_kwargs["processing_class"] = tokenizer
    elif "tokenizer" in trainer_parameters:
        trainer_kwargs["tokenizer"] = tokenizer

    trainer = DPOTrainer(**filter_supported_kwargs(DPOTrainer, trainer_kwargs))
    trainer.train()

    dpo_adapter_dir = Path(output_config["adapter_dir"])
    dpo_adapter_dir.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(str(dpo_adapter_dir))
    tokenizer.save_pretrained(str(dpo_adapter_dir))
    print(f"Saved DPO LoRA adapter to {dpo_adapter_dir}")

    if args.merge:
        merged_dir = Path(output_config["merged_dir"])
        merged_dir.mkdir(parents=True, exist_ok=True)
        model.save_pretrained_merged(str(merged_dir), tokenizer, save_method="merged_16bit")
        print(f"Saved DPO merged model to {merged_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
