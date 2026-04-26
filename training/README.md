# TabAnywhere Training Pipeline

This directory contains the local-first fine-tuning and evaluation pipeline for
TabAnywhere's unified edit prediction model.

The model task is intentionally the same task used by the app:

```text
input: app/window/context + editable text window with <|caret|>
target: rewritten editable text window with exactly one <|caret|>
```

A completion is a rewrite whose diff is an insertion at the caret. An edit is a
rewrite whose diff changes existing text. The model never emits JSON patches;
the app computes patches deterministically from the rewrite.

## Layout

- `data/seed/`: curated SFT examples.
- `data/eval/`: frozen evaluation examples.
- `data/preference/`: DPO/preference pairs for later restraint tuning.
- `data/raw/`: local opt-in exports before redaction and review. Ignored by git.
- `schemas/`: JSON schema documentation for dataset records.
- `prompts/`: training/inference prompt contract.
- `scripts/`: local validation, prompt rendering, scoring, and data prep tools.
- `configs/`: training, eval, and GGUF export configuration.
- `runs/`: local training/eval outputs. Ignored by git.
- `models/`: exported LoRA/GGUF artifacts. Ignored by git.

## First Pass Workflow

### Python Environment

Use `uv` for the local training tooling environment. `mise` is still useful as a
global language-version manager, but `uv` is the better fit here because it owns
the virtual environment, dependency syncing, and optional training extras in one
place.

The local macOS environment is mainly for dataset validation, prompt rendering,
and packaging jobs. Actual Unsloth training should run on Linux with a CUDA GPU.

```bash
cd training
uv venv --python 3.12
source .venv/bin/activate
uv pip install -e .
```

For a cloud GPU training box:

```bash
cd training
uv venv --python 3.12
source .venv/bin/activate
uv pip install -e ".[training]"
```

If `uv` cannot find Python 3.12 locally, install it with your preferred manager
or let `uv` install it:

```bash
uv python install 3.12
```

Google Colab can skip the repo venv and install directly in the notebook runtime:

```bash
pip install unsloth
pip install -r training/requirements-training.txt
```

For Colab or the VS Code Colab extension, use:

```text
training/notebooks/tabanywhere_gemma4_unsloth_colab.ipynb
```

Recommended GPU order:

1. L4 24 GB: best default for Gemma 4 E4B QLoRA experiments.
2. A100 40 GB: fastest and most reliable if available.
3. T4 16 GB: acceptable for a smoke test with short context and small batches.

The notebook expects the repo to be available from a Git URL. If the repo is
private, create Colab secrets named `GITHUB_TOKEN` and `HF_TOKEN`.

1. Validate datasets:

   ```bash
   python3 training/scripts/validate_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl --kind sft
   python3 training/scripts/validate_dataset.py training/data/eval/tabanywhere_eval_v001.jsonl --kind eval
   python3 training/scripts/validate_dataset.py training/data/preference/tabanywhere_dpo_v001.jsonl --kind preference
   ```

2. Render a prompt/target pair for inspection:

   ```bash
   python3 training/scripts/render_prompt.py training/data/seed/tabanywhere_seed_v001.jsonl --id seed-0001
   ```

3. Run a deterministic prediction-file eval:

   ```bash
   python3 training/scripts/score_predictions.py training/data/eval/tabanywhere_eval_v001.jsonl predictions.jsonl
   ```

4. Train with LoRA/QLoRA using `configs/sft_gemma_lora.yaml`.

   ```bash
   python3 training/scripts/split_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl --out-dir training/runs/splits
   python3 training/scripts/prepare_sft_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl training/runs/seed_messages.jsonl
   python3 training/scripts/train_unsloth_qlora.py --config training/configs/sft_gemma_lora.yaml --merge
   ```

5. Export GGUF variants with `configs/export_gguf.yaml`, then benchmark in the
   macOS app.

   ```bash
   python3 training/scripts/export_gguf_unsloth.py --config training/configs/export_gguf.yaml
   ```

## Data Principles

- Include many no-op cases. Restraint is a primary behavior.
- Allow longer completions only when the existing text strongly constrains what
  should follow.
- Do not train invented facts, excuses, names, dates, links, commitments, or
  sensitive personal details.
- Preserve tone and formatting.
- Keep edits local and patchable by the app's diff validator.
