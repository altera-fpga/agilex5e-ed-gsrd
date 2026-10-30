#!/usr/bin/env python3
"""hps-amp source fetcher.

Reads a YAML manifest (default: ./sources.yaml) and clones / checks out /
patches every external source tree declared in it. Idempotent and re-runnable;
intended as the single replacement for `git submodule update --init` plus the
old per-component `*-fetch` Makefile targets.

Usage:
  fetch-sources.py                           # fetch all components, apply patches
  fetch-sources.py --only bao --only linux   # fetch a subset
  fetch-sources.py --use-lock                # use sources.lock.yaml refs (CI/ship default)
  fetch-sources.py --update-lock             # rewrite sources.lock.yaml from current HEADs
  fetch-sources.py --no-patches              # fetch only, skip patch apply (and skip reset)
  fetch-sources.py --reset                   # `git reset --hard && clean -fdx` each dest
  fetch-sources.py --dry-run                 # print what would be done

Per-component env-var overrides (uppercased name, dashes -> underscores):
  HPS_AMP_<NAME>_URL   override `url`
  HPS_AMP_<NAME>_REF   override `ref`

Examples:
  HPS_AMP_LINUX_URL=https://my.fork/linux \
  HPS_AMP_LINUX_REF=v6.12 ./scripts/fetch-sources.py --only linux
"""
from __future__ import annotations

import argparse
import datetime as _dt
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    sys.exit(
        "error: PyYAML not found.\n"
        "       Install it once on this host:\n"
        "         pip3 install --user pyyaml\n"
        "       or:\n"
        "         sudo apt install python3-yaml      # Debian/Ubuntu\n"
        "         sudo dnf install python3-pyyaml    # Fedora/RHEL"
    )


# --------------------------------------------------------------------------- #
# Tiny logging helpers (mirror scripts/lib.sh look-and-feel).
# --------------------------------------------------------------------------- #

def _c(code: str, text: str) -> str:
    if not sys.stdout.isatty():
        return text
    return f"\033[{code}m{text}\033[0m"


def step(msg: str) -> None:
    print(_c("1;34", ">>>"), msg, flush=True)


def info(msg: str) -> None:
    print("   ", msg, flush=True)


def warn(msg: str) -> None:
    print(_c("1;33", "WARN:"), msg, flush=True)


def die(msg: str) -> "NoReturn":  # type: ignore[valid-type]
    print(_c("1;31", "ERROR:"), msg, file=sys.stderr, flush=True)
    sys.exit(1)


# --------------------------------------------------------------------------- #
# Manifest schema validation.
# --------------------------------------------------------------------------- #

_VALID_REF_KINDS = {"sha", "tag", "branch"}
_REQUIRED_FIELDS = ("name", "url", "ref", "ref_kind", "dest")


def load_manifest(path: Path) -> list[dict]:
    if not path.exists():
        die(f"manifest not found: {path}")
    with path.open() as fh:
        doc = yaml.safe_load(fh) or {}
    schema = doc.get("schema_version")
    if schema != 1:
        die(f"unsupported sources.yaml schema_version {schema!r} (expected 1)")
    comps = doc.get("components") or []
    if not isinstance(comps, list) or not comps:
        die("manifest 'components' must be a non-empty list")
    names: set[str] = set()
    for i, c in enumerate(comps):
        if not isinstance(c, dict):
            die(f"component[{i}] must be a mapping, got {type(c).__name__}")
        for f in _REQUIRED_FIELDS:
            if c.get(f) in (None, ""):
                die(f"component[{i}] missing required field '{f}'")
        if c["ref_kind"] not in _VALID_REF_KINDS:
            die(
                f"component '{c['name']}' has invalid ref_kind={c['ref_kind']!r} "
                f"(must be one of {sorted(_VALID_REF_KINDS)})"
            )
        if c["name"] in names:
            die(f"duplicate component name {c['name']!r}")
        names.add(c["name"])
        c["ref"] = str(c["ref"])
        c.setdefault("patches", "")
        c.setdefault("recurse_submodules", False)
    return comps


def load_lock(path: Path) -> dict[str, str]:
    if not path.exists():
        die(f"lock file not found: {path} (run `make pin` to create one)")
    with path.open() as fh:
        doc = yaml.safe_load(fh) or {}
    if doc.get("schema_version") != 1:
        die(f"unsupported sources.lock.yaml schema_version {doc.get('schema_version')!r}")
    comps = doc.get("components") or {}
    out: dict[str, str] = {}
    for name, entry in comps.items():
        if not isinstance(entry, dict) or "ref" not in entry:
            die(f"lock entry for {name!r} missing 'ref'")
        out[name] = str(entry["ref"])
    return out


# --------------------------------------------------------------------------- #
# Env-var overrides.
# --------------------------------------------------------------------------- #

def _env_key(name: str, suffix: str) -> str:
    return "HPS_AMP_" + name.upper().replace("-", "_") + "_" + suffix


def apply_env_overrides(c: dict) -> dict:
    url_env = os.environ.get(_env_key(c["name"], "URL"))
    ref_env = os.environ.get(_env_key(c["name"], "REF"))
    if url_env:
        info(f"  env override: {c['name']}.url = {url_env}")
        c = {**c, "url": url_env}
    if ref_env:
        info(f"  env override: {c['name']}.ref = {ref_env}")
        c = {**c, "ref": ref_env}
    return c


# --------------------------------------------------------------------------- #
# git helpers.
# --------------------------------------------------------------------------- #

def run(cmd: list[str], *, cwd: Optional[Path] = None, check: bool = True,
        capture: bool = False, dry_run: bool = False) -> subprocess.CompletedProcess:
    pretty = " ".join(shlex.quote(x) for x in cmd)
    if cwd:
        info(f"$ (cd {cwd}) {pretty}")
    else:
        info(f"$ {pretty}")
    if dry_run:
        return subprocess.CompletedProcess(cmd, 0, "", "")
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def is_git_worktree(p: Path) -> bool:
    return (p / ".git").exists()


def head_sha(p: Path) -> str:
    cp = run(["git", "-C", str(p), "rev-parse", "HEAD"], capture=True)
    return cp.stdout.strip()


# --------------------------------------------------------------------------- #
# Per-component actions.
# --------------------------------------------------------------------------- #

def clone(c: dict, root: Path, *, dry_run: bool) -> None:
    dest = root / c["dest"]
    if is_git_worktree(dest):
        info(f"{c['name']}: already at {dest}, skipping clone")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if c["ref_kind"] in ("tag", "branch"):
        run(
            [
                "git", "clone",
                "--depth", "1",
                "-b", str(c["ref"]),
                "--no-tags",
                "--no-recurse-submodules",
                c["url"],
                str(dest),
            ],
            dry_run=dry_run,
        )
    else:  # sha
        # Shallow clone can't reach arbitrary SHAs reliably across all servers,
        # but the destination repos here (github.com mirrors) allow fetching a
        # specific SHA into a shallow tree. Use that path to keep clones small.
        run(
            [
                "git", "init", "-q", str(dest),
            ],
            dry_run=dry_run,
        )
        run(["git", "-C", str(dest), "remote", "add", "origin", c["url"]], dry_run=dry_run)
        # uploadpack.allowReachableSHA1InWant / allowAnySHA1InWant are enabled
        # on github.com, so this fetch works for any commit on origin.
        run(
            [
                "git", "-C", str(dest),
                "fetch", "--depth", "1", "--no-tags",
                "--no-recurse-submodules", "origin", str(c["ref"]),
            ],
            dry_run=dry_run,
        )
        run(
            ["git", "-C", str(dest), "checkout", "--detach", "FETCH_HEAD"],
            dry_run=dry_run,
        )


def _ensure_origin(c: dict, dest: Path, *, dry_run: bool) -> None:
    """If origin disagrees with manifest url, repoint it.

    Covers two cases:
      * sources.yaml's url was bumped after first clone.
      * Pre-migration submodule clone used a different URL than the manifest
        default (e.g. config.mk LINUX_REPO override points at a different fork).
    """
    if dry_run:
        info(f"$ (cd {dest}) git remote set-url origin {c['url']}  [if mismatched]")
        return
    cp = run(
        ["git", "-C", str(dest), "remote", "get-url", "origin"],
        check=False, capture=True,
    )
    current = cp.stdout.strip() if cp.returncode == 0 else ""
    if current == c["url"]:
        return
    if cp.returncode != 0:
        info(f"{c['name']}: adding origin = {c['url']}")
        run(["git", "-C", str(dest), "remote", "add", "origin", c["url"]])
    else:
        info(f"{c['name']}: origin {current} != {c['url']}, repointing")
        run(["git", "-C", str(dest), "remote", "set-url", "origin", c["url"]])


def reset_to_ref(c: dict, root: Path, *, dry_run: bool) -> None:
    """Make existing worktree match `ref` exactly (drops local edits + patches)."""
    dest = root / c["dest"]
    if not is_git_worktree(dest):
        return
    run(["git", "-C", str(dest), "reset", "--hard"], dry_run=dry_run)
    run(["git", "-C", str(dest), "clean", "-fdx"], dry_run=dry_run)
    _ensure_origin(c, dest, dry_run=dry_run)
    if c["ref_kind"] in ("tag", "branch"):
        run(
            ["git", "-C", str(dest), "fetch", "--depth", "1", "--no-tags",
             "--no-recurse-submodules", "origin", str(c["ref"])],
            dry_run=dry_run,
        )
        run(
            ["git", "-C", str(dest), "checkout", "--detach", "FETCH_HEAD"],
            dry_run=dry_run,
        )
    else:  # sha
        # Try local first (cheap); fall back to a fetch of the specific SHA.
        cp = run(
            ["git", "-C", str(dest), "cat-file", "-e", str(c["ref"])],
            check=False, capture=True, dry_run=dry_run,
        )
        if cp.returncode != 0 and not dry_run:
            run(
                ["git", "-C", str(dest), "fetch", "--depth", "1", "--no-tags",
                 "--no-recurse-submodules", "origin", str(c["ref"])],
            )
        run(
            ["git", "-C", str(dest), "checkout", "--detach", str(c["ref"])],
            dry_run=dry_run,
        )


def apply_patches(c: dict, root: Path, *, dry_run: bool) -> None:
    patches_rel = c.get("patches") or ""
    if not patches_rel:
        info(f"{c['name']}: no patch dir, skipping")
        return
    patches_dir = root / patches_rel
    if not patches_dir.is_dir():
        info(f"{c['name']}: patch dir {patches_dir} missing, skipping")
        return
    patches = sorted(patches_dir.glob("*.patch"))
    if not patches:
        info(f"{c['name']}: no *.patch under {patches_dir}, skipping")
        return
    dest = root / c["dest"]
    step(f"[{c['name']}] applying {len(patches)} patch(es) from {patches_rel}")
    for p in patches:
        info(f"  {p.name}")
        run(
            ["git", "-C", str(dest), "apply", "--whitespace=nowarn", str(p)],
            dry_run=dry_run,
        )


def maybe_recurse_submodules(c: dict, root: Path, *, dry_run: bool) -> None:
    if not c.get("recurse_submodules"):
        return
    dest = root / c["dest"]
    run(
        ["git", "-C", str(dest), "submodule", "update", "--init", "--depth", "1"],
        dry_run=dry_run,
    )


# --------------------------------------------------------------------------- #
# Lock-file writer.
# --------------------------------------------------------------------------- #

def write_lock(path: Path, comps: list[dict], root: Path) -> None:
    out_comps: dict = {}
    for c in comps:
        dest = root / c["dest"]
        if not is_git_worktree(dest):
            warn(f"{c['name']}: {dest} not a git worktree, skipping in lock")
            continue
        out_comps[c["name"]] = {"ref": head_sha(dest)}
    doc = {
        "schema_version": 1,
        "generated_at": _dt.datetime.now(tz=_dt.timezone.utc)
            .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "components": out_comps,
    }
    header = (
        "# AUTO-GENERATED by `make pin`.\n"
        "# Records resolved HEAD SHA per component for reproducible builds.\n"
        "# `make fetch-lock` reads this file and ignores `ref` in sources.yaml.\n\n"
    )
    body = yaml.safe_dump(doc, sort_keys=False, default_flow_style=False)
    path.write_text(header + body)
    step(f"wrote {path} ({len(out_comps)} components)")


# --------------------------------------------------------------------------- #
# Driver.
# --------------------------------------------------------------------------- #

def _depth(c: dict) -> int:
    return c["dest"].count("/")


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(
        description="hps-amp manifest-driven source fetcher",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    # Script lives at <solution>/scripts/fetch-sources.py, so:
    #   here = <solution>/   (holds sources.yaml, sources.lock.yaml, and every
    #                          component dir <c>/src + <c>/patches).
    # The solution is self-contained, so dest: paths are solution-relative and
    # --root defaults to `here`.
    here = Path(__file__).resolve().parent.parent
    p.add_argument("--manifest", default=str(here / "sources.yaml"), type=Path)
    p.add_argument("--lock", default=str(here / "sources.lock.yaml"), type=Path)
    p.add_argument("--root", default=str(here), type=Path,
                   help="solution dir the dest: paths resolve against (default: this solution)")
    p.add_argument("--only", action="append", metavar="NAME",
                   help="restrict to this component (repeatable)")
    p.add_argument("--use-lock", action="store_true",
                   help="override manifest refs with sources.lock.yaml")
    p.add_argument("--update-lock", action="store_true",
                   help="write sources.lock.yaml from current HEADs after fetch")
    p.add_argument("--no-patches", action="store_true",
                   help="skip patch-apply (and skip reset-to-ref)")
    p.add_argument("--reset", action="store_true",
                   help="reset worktrees to ref before patching (default when patches applied)")
    p.add_argument("--dry-run", action="store_true",
                   help="print git commands without executing")
    args = p.parse_args(argv)

    comps = load_manifest(args.manifest)

    if args.only:
        wanted = set(args.only)
        unknown = wanted - {c["name"] for c in comps}
        if unknown:
            die(f"--only references unknown components: {sorted(unknown)}")
        comps = [c for c in comps if c["name"] in wanted]

    if args.use_lock:
        lock = load_lock(args.lock)
        new_comps: list[dict] = []
        for c in comps:
            if c["name"] in lock:
                step(f"[{c['name']}] lock pin {lock[c['name']]}")
                new_comps.append({**c, "ref": lock[c["name"]], "ref_kind": "sha"})
            else:
                warn(f"{c['name']} not in lock — using manifest ref {c['ref']}")
                new_comps.append(c)
        comps = new_comps

    comps = [apply_env_overrides(c) for c in comps]

    # Sort by destination depth so parent trees materialise first
    # (e.g. freertos/src before freertos/src/FreeRTOS/Source).
    comps.sort(key=_depth)

    if shutil.which("git") is None:
        die("git not found in PATH")

    for c in comps:
        step(f"[{c['name']}] {c['url']}  @ {c['ref']}  ({c['ref_kind']})  -> {c['dest']}")
        clone(c, args.root, dry_run=args.dry_run)
        if not args.no_patches:
            reset_to_ref(c, args.root, dry_run=args.dry_run)
        maybe_recurse_submodules(c, args.root, dry_run=args.dry_run)
        if not args.no_patches:
            apply_patches(c, args.root, dry_run=args.dry_run)

    if args.update_lock and not args.dry_run:
        write_lock(args.lock, comps, args.root)

    step("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
