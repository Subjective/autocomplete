# Training Environment Setup

Use `uv` for the Python virtual environment and package management. `mise` is
useful for pinning tool versions, but `uv` is the simpler source of truth for
this training pipeline.

## Local Mac Setup

The local Mac environment is useful for dataset validation, prompt rendering,
and preparing JSONL files. It is not the right place to run Unsloth QLoRA
training unless the machine has a supported CUDA GPU.

Recommended local setup:

```bash
uv venv training/.venv --python 3.12
source training/.venv/bin/activate
uv pip install pyyaml
```

Then run the local tools:

```bash
python training/scripts/validate_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl --kind sft
python training/scripts/render_prompt.py training/data/seed/tabanywhere_seed_v001.jsonl --id seed-0005
python training/scripts/prepare_sft_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl training/runs/seed_messages.jsonl
```

## GPU Training Setup

Run the actual Unsloth training on a Linux CUDA machine, Colab, RunPod,
Lambda Labs, Vast.ai, Modal, or another GPU environment.

Baseline setup:

```bash
uv venv .venv --python 3.12
source .venv/bin/activate
uv pip install -r training/requirements-training.txt
huggingface-cli login
python training/scripts/split_dataset.py training/data/seed/tabanywhere_seed_v001.jsonl --out-dir training/runs/splits
python training/scripts/train_unsloth_qlora.py --config training/configs/sft_gemma_lora.yaml --merge
python training/scripts/split_dataset.py training/data/preference/tabanywhere_dpo_v001.jsonl --out-dir training/runs/dpo_splits
python training/scripts/train_unsloth_dpo.py --config training/configs/dpo_gemma_lora.yaml --merge
python training/scripts/export_gguf_unsloth.py --config training/configs/export_dpo_gguf.yaml
```

If `google/gemma-4-E4B-it` is gated, accept the model license on Hugging Face
before running `huggingface-cli login`.

## Colab

Colab is enough for a first smoke test if you use a small curated dataset, low
batch size, and QLoRA. A free T4 can be tight for a 4B model with 2048-token
windows, but it is useful for proving the script and dataset. Colab Pro with
L4/A100 is a better first real training run.

Use Unsloth's Colab install path in a fresh runtime:

```bash
pip uninstall -y unsloth unsloth_zoo
pip install --upgrade --no-cache-dir "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
pip install --upgrade --no-cache-dir "git+https://github.com/unslothai/unsloth-zoo.git"
pip install --upgrade --no-cache-dir datasets huggingface_hub pyyaml accelerate
```

If a run has already imported Torch, Transformers, TRL, or Unsloth before this
install step, restart the Colab runtime after installation and rerun from the
top. That avoids mixed CUDA/Torch extension state.

Suggested first Colab settings:

- `max_sequence_length: 2048`
- `per_device_train_batch_size: 1`
- `gradient_accumulation_steps: 8`
- `epochs: 1`
- start with 50-100 reviewed examples

Then move to a paid GPU for the 300-800 example run.

## Recommendation

- Use `uv` for venvs and dependency installs.
- Use Python 3.12 for the training environment.
- Use the local Mac only for data/eval tooling.
- Use Colab Pro L4/A100 or a rented CUDA GPU for actual QLoRA training.
