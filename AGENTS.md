# Agilex 5 E-Series Baseline Hardware Reference Design — Agent Guide

Concise guidance for AI agents and local developers working in this repository: how to find
designs, run builds, and edit safely.

**Human customers** should start with [README.md](README.md). This file ships with external
releases and must stand alone when internal-only directories are stripped.

## Checkout variant

External releases remove `.github/` and `not_shipped/` (`rm -rf .github not_shipped` on publish).
If a path referenced below does not exist in your checkout, skip it — do not treat that as an error.

| Path | Shipped | Purpose |
|------|---------|---------|
| `dk-*`, `mk-*`, `terasic-*` | Yes | Platform folders containing Baseline Hardware Reference Designs |
| [platform_config.mk](platform_config.mk) | Yes | Platforms in the root build matrix |
| [README.md](README.md) | Yes | Product overview, devkit index, build quick start |
| `.github/` | No | CI/CD workflows and automation (YAML + workflow docs) |
| `.cursor/` | No | Cursor agent rules (excluded from public publish rsync) |
| `not_shipped/` | No | Regtest, legacy designs, extended dev guides |

## Find a design

Use this flow to index any design in the repo (no static list required):

1. [platform_config.mk](platform_config.mk) — authoritative list of shipped platform folders
2. [README.md](README.md) `#designs` — devkit-oriented index with links to designs
3. `<platform>/README.md` — designs on that platform (when present)
4. `<platform>/<design>/README.md` — functional description, metadata, software links
5. `<platform>/<design>/software/*/README.md` — Yocto, HPS debug, FreeRTOS, etc.

Discover make targets:

```bash
make help
make -C <platform> print-targets
make -C <platform>/<design> print-sw-targets
```

## Documentation map (shipped tree)

| Tier | Location | Use when |
|------|----------|----------|
| 1 | [README.md](README.md) | Repository overview, dependencies, `#designs` index |
| 2 | `<platform>/README.md` | Devkit context; design index for that platform |
| 3 | `<platform>/<design>/README.md` | Design features, QP_INFO metadata, software links |
| 4 | `<design>/software/*/README.md` | Build and usage for a software stack |
| 5 | Yocto `meta-custom/**/README.md` | Recipe-specific edits only (optional leaf) |

Design READMEs contain Markdown metadata for `quartus_sh --validate_metadata`. Do not remove or break
that structure.

### Design package (zip) — editing customer READMEs

Customers often receive **only one design `.zip`**, not the full repository. When editing design or
software READMEs, they must work standalone: no upward links and **no prose references** to the
repository root or platform README. Document **design-directory** `Makefile` targets the zip ships
and Altera tests (e.g. `make prep`, `make sim`). See
[not_shipped/docs/guides/USER_FACING_README.md](not_shipped/docs/guides/USER_FACING_README.md) (internal
checkout) for full policy.

## Quick start

```bash
quartus_sh -v
make dk-a5e065ab32aea-enablement-baseline-a55-all
```

Outputs under `install/`; intermediates under `work/` and `<design>/output_files/`.

## Makefile hierarchy

```
Makefile → <platform>/Makefile → <design>/Makefile → software/*.mk
```

| Level | Example target |
|-------|----------------|
| Repo root | `make dk-a5e065ab32aea-enablement-baseline-a55-all` |
| Platform dir | `make baseline-a55-build` |
| Software | `make software-yocto_linux_sd-build-sw` |

Root `...-all` runs: `pre-prep` → `generate-design` → `package-design` → `prep` → `build` →
`functional-sim` → `test` → `install` → default SW build/install. Default SW target depends on
platform suffix (`-emmc`, `-nand`, or SD Yocto).

Prefer **root-level** `make <platform>-<design>-<stage>` targets from the repository root.

## Environment setup

- Quartus Prime Pro **26.3**, Python **3.11.5**, Linux (SLES 15 SP4 tested).
- **Internal checkout (Altera dev hosts):** Quartus is provided through **ARC**, not a manual
  `PATH` export. Wrap Quartus-dependent commands (including
  `make -j style-check-readme-metadata` after README edits):

  ```bash
  arc shell --no-inherit $(cat .github/arc_resource.txt) -- $COMMAND
  ```

  See [not_shipped/docs/AGENTS.md](not_shipped/docs/AGENTS.md) for ARC syntax, examples, and
  exceptions. Skip this block when `.github/` or `not_shipped/` is absent (external release).
- **External / local Quartus install:** set `QUARTUS_ROOTDIR` and extend `PATH`:

```bash
export QUARTUS_ROOTDIR=~/alteraFPGA_pro/26.3/quartus
export PATH="$QUARTUS_ROOTDIR/bin:$QUARTUS_ROOTDIR/../qsys/bin:$QUARTUS_ROOTDIR/../niosv/bin:$QUARTUS_ROOTDIR/sopc_builder/bin:$QUARTUS_ROOTDIR/../questa_fe/bin:$QUARTUS_ROOTDIR/../syscon/bin:$QUARTUS_ROOTDIR/../riscfree/RiscFree:$PATH"
```

Verify: `quartus_sh -v` and `make print-env`.

- `make venv` creates the Python environment from [requirements.txt](requirements.txt).

## Software builds (summary)

Designs with modular software use `swbuild_config.mk` and `software/<project>.mk` (`clean-sw`,
`build-sw`, `install-sw`). Reference layout: `dk-a5e065ab32aea-enablement/baseline-a55/`.

- SW-only when a bitstream already exists: `RESTORE_INSTALL=1`
- Modular SW port work: see `not_shipped/docs/projects/sw-build-refactor/AGENTS.md` (checklist, `repo-files-check` Makefile sync groups, VDS `ip-upgrade-helper` policy).

## Safe editing

- Keep changes minimal and design-scoped; do not alter unrelated platforms.
- Do not rename public make targets or edit [platform_config.mk](platform_config.mk) unless required.
- Do not add license headers unless requested.
- Avoid regenerating Qsys/Quartus outputs unless necessary.
- Do not commit artifacts under `install/` or `work/`.
- Do not mix GUI and CLI builds in the same working tree; run `make clean` if switching methods.

## Common commands

```bash
make print-env
make clean
make venv
```

## Troubleshooting

| Issue | Action |
|-------|--------|
| Missing Quartus | Check `QUARTUS_ROOTDIR` and `PATH` |
| Python errors | `make venv`, confirm Python 3.11 |
| GUI/CLI conflict | `make clean`, use one flow per session |
| Missing SW targets | Check `swbuild_config.mk` and `SW_PROJECT_LIST` in the design Makefile |
| Metadata validation failure | Fix Project Details / Documentations blocks in the design README |

## Extended docs (internal checkout only)

If these paths **exist**, read them for additional depth. They are removed on external release.

| Path | Read when |
|------|-----------|
| [not_shipped/docs/GETTING_STARTED.md](not_shipped/docs/GETTING_STARTED.md) | Internal doc hub — active projects, onboarding |
| [not_shipped/docs/AGENTS.md](not_shipped/docs/AGENTS.md) | ARC shell, internal agent rules, CI doc pointers |
| [not_shipped/docs/DEVELOPMENT.md](not_shipped/docs/DEVELOPMENT.md) | Full Makefile matrix, regtest, formatting, submodule setup |
| [not_shipped/docs/guides/USER_FACING_README.md](not_shipped/docs/guides/USER_FACING_README.md) | Rules for editing customer README navigation and metadata |
