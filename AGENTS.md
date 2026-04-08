# Agilex 5 E-Series GHRD Agent Guide

## Purpose

- Provide concise, actionable guidance for agents working on the Agilex 5 E‑Series GHRD workspace.
- Focus on build flows, environment setup, safe edits, and common operations.

## Quick Start (CLI)

- Ensure Quartus tools are on `PATH` (see Environment Setup).
- Sanity check the toolchain:

```bash
quartus_sh -v
which quartus_sh
```

- Build one design from the repo root (pick a target from [README.md](README.md)):

```bash
make a5ed065es-premium-devkit-oobe-baseline-a55-all
```

- Outputs land under `install/` (see Artifacts Layout). Intermediate build products land under `work/`.

## Scope

- This repo hosts Golden Hardware Reference Designs (GHRD) for Agilex 5 E‑Series SoC FPGA.
- Designs live under platform folders (e.g., a5ed065es‑premium‑devkit‑oobe/, a5ed013‑devkit‑oobe/) with variants like `baseline-a55`, `baseline-a76`, and legacy designs.
- Use Quartus Prime Pro for hardware builds; optional Python tooling for CLI orchestration.

## Environment Setup

- Required tools: Altera Quartus Prime Pro, Python 3.11.5.
- Linux is the supported build OS; SUSE Linux Enterprise Server 15 SP4 tested.
- Minimal environment to enable CLI builds:
  - Set `QUARTUS_ROOTDIR` to your Quartus Prime Pro installation.
  - Add Quartus and related tool bins to `PATH`.

```bash
# Example environment (adjust for installation path/version)
export QUARTUS_ROOTDIR=~/alteraFPGA_pro/26.1/quartus
export PATH="$QUARTUS_ROOTDIR/bin:$QUARTUS_ROOTDIR/../qsys/bin:$QUARTUS_ROOTDIR/../niosv/bin:$QUARTUS_ROOTDIR/sopc_builder/bin:$QUARTUS_ROOTDIR/../questa_fe/bin:$QUARTUS_ROOTDIR/../syscon/bin:$QUARTUS_ROOTDIR/../riscfree/RiscFree:$PATH"
```

## Sanity Checks

- Confirm the Quartus install is reachable:

```bash
quartus_sh -v
```

- If `quartus_sh` is missing, re-check `QUARTUS_ROOTDIR` and `PATH`.

## Python Virtualenv

- The top‑level Makefile will create a local venv and install dependencies from [requirements.txt](requirements.txt) when building.
- The venv directory is `venv/` by default.
- To prepare tools explicitly:

```bash
make venv
```

- If you need to use a specific Python:

```bash
make PYTHON3=/path/to/python3.11 venv
```

## Repo Structure & Targets

- Top‑level aggregation Makefile orchestrates per‑platform sub‑targets listed in [platform_config.mk](platform_config.mk).
- Each platform folder has its own Makefile and per‑design targets.
- Common top‑level phony targets:
  - `pre-prep`, `prep`, `ip-upgrade`, `generate-designs`, `package-designs`, `build`, `test`, `install`, `build-sw`, `install-sw`, `all`.
- The `all` target chains the full flow across all configured platforms/designs.

## Target Discovery

- Use the root [README.md](README.md) “Designs” section for the canonical `make <platform>-<design>-all` targets.
- Platform and design folders typically also provide a help/listing:

```bash
make -C a5ed065es-premium-devkit-oobe help
make -C a5ed065es-premium-devkit-oobe print-targets
```

## What `...-all` Does

- The root `make <platform>-<design>-all` meta target runs the standard pipeline in order:
  `pre-prep` → `generate-design` → `package-design` → `prep` → `build` → `test` → `install` → `build-sw` → `install-sw`.

## Typical Build Flow (CLI)

- Run design‑specific meta targets from the repo root; outputs go under `install/`.
- Examples from [README.md](README.md):

```bash
# Premium Devkit ES, Baseline-A55
make a5ed065es-premium-devkit-oobe-baseline-a55-all

# Premium Devkit ES, Baseline-A76
make a5ed065es-premium-devkit-oobe-baseline-a76-all

# Legacy TSN CFG2 (Premium Devkit ES)
make a5ed065es-premium-devkit-oobe-legacy-tsn-cfg2-all

# Debug2 / EMMC / Modular / 013 Devkit legacy designs
make a5ed065es-premium-devkit-debug2-legacy-baseline-all
make a5ed065es-premium-devkit-emmc-legacy-baseline-all
make a5ed065es-modular-devkit-som-legacy-baseline-all
make a5ed013-devkit-oobe-legacy-baseline-all
```

## Quartus GUI Flow

- Open `.qpf` in the target design folder (e.g., a premium devkit baseline project) and compile from the GUI. Compiled `.sof` appears in the project `output_files`.

- Avoid mixing GUI and CLI builds in the same working tree. If you switch methods, do a clean first:

```bash
make clean
```

## Artifacts Layout

- After builds:
  - Zipped project archives under `install/designs/`.
  - Bitstreams and software under `install/binaries/<platform>/<design>/`.
  - Additional artifacts under `install/artifacts/`.

- Intermediate build outputs are under `work/` (safe to delete via `make clean`).

## Coding/Formatting

- Python: Black (line length 88) and Flake8 settings in [pyproject.toml](pyproject.toml).
- SystemVerilog formatting: see [verible-format.txt](verible-format.txt).
- Avoid mixing GUI and CLI builds in the same working tree; it can break generated filesets.

## Safe Editing Guidelines

- Keep changes minimal and design‑scoped; do not alter unrelated platforms.
- Respect existing Makefile contracts and variable names; avoid changing public target names.
- Avoid editing [platform_config.mk](platform_config.mk) unless the task explicitly requires changing which platforms/designs are included.
- Do not add license headers unless explicitly requested.
- For shell/Make variables controlling parallelism, prefer using `nproc` safely:
  - Example: `JOBS ?= $(shell nproc)` in Makefiles or `NUM_JOBS="${NUM_JOBS:-$(nproc)}"` in shell.
- When editing QSYS/Quartus TCL, follow pattern‑safe filtering and avoid noisy `puts` unless gated by intent.

- Avoid re-generating Qsys/Quartus outputs unless required; it can introduce large diffs and break reproducibility.

## Common Tasks

- Print environment:

```bash
make print-env
```

- Update workspace:

```bash
make dev-update
```

- Clean builds:

```bash
make clean       # removes build outputs (keeps venv)
make dev-clean   # deeper clean; removes install/work and untracked files
```

## Design Navigation

- Per‑platform design docs live inside platform folders, e.g., see [a5ed013-devkit-oobe/baseline-a55/README.md](a5ed013-devkit-oobe/baseline-a55/README.md) for features and subsystem details.

## Do/Don’t

- Do verify the Quartus toolchain is active via `quartus_sh -v` before building.
- Do use top‑level `make <platform>-<design>-all` when unsure; it runs the full pipeline.
- Don’t commit outputs under `install/` unless release workflow requires; treat as build artifacts.
- Don’t modify `.github/` or `not_shipped/` for agent work unless explicitly tasked; these are out of scope.

## Troubleshooting Notes

- If builds fail due to environment: re‑export `QUARTUS_ROOTDIR` and verify `PATH` includes Quartus and Qsys tools.
- If Python tooling errors: re‑run `make venv` and ensure Python 3.11 is available.
- If GUI vs CLI conflicts: perform a clean (`make clean`) and stick to one method per session.

## Contact/Docs

- Refer to the root [README.md](README.md) for quick‑start and platform‑specific make invocations.
- External documentation links in platform READMEs cover HPS, EMIF, bridges, and Yocto software guidance.
