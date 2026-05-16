#!/usr/bin/env python3
"""Temporarily prune release-only icon/startup media resources before Hvigor packaging.

This script never deletes source resources permanently.  --apply moves only redundant
app_icon*/startup_foreground* files into a gitignored stash under .hermes-artifacts;
--restore moves them back and verifies the source tree is restored.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_ROOT = ROOT / ".hermes-artifacts" / "release-media-resource-prune"
STASH_DIR = ARTIFACT_ROOT / "stash"
MANIFEST_PATH = ARTIFACT_ROOT / "manifest.json"

MEDIA_DIRS = [
    ROOT / "entry/src/main/resources/base/media",
    ROOT / "AppScope/resources/base/media",
]
REFERENCE_FILES = [
    ROOT / "AppScope/app.json5",
    ROOT / "entry/src/main/module.json5",
    ROOT / "entry/src/main/resources/base/profile/main_pages.json",
]
PRUNE_PREFIXES = ("app_icon", "startup_foreground")
RESOURCE_EXTENSIONS = (".json", ".png", ".webp", ".jpg", ".jpeg", ".svg")
MEDIA_REF_RE = re.compile(r"\$media:([A-Za-z0-9_]+)")


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def find_media_refs(value: Any) -> set[str]:
    refs: set[str] = set()
    if isinstance(value, str):
        refs.update(MEDIA_REF_RE.findall(value))
    elif isinstance(value, dict):
        for item in value.values():
            refs.update(find_media_refs(item))
    elif isinstance(value, list):
        for item in value:
            refs.update(find_media_refs(item))
    return refs


def parse_json_resource(path: Path) -> Any | None:
    try:
        return json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"failed to parse JSON resource {rel(path)}: {exc}") from exc


def discover_initial_media_refs() -> set[str]:
    refs: set[str] = set()
    for path in REFERENCE_FILES:
        if path.exists():
            refs.update(MEDIA_REF_RE.findall(read_text(path)))
    return refs


def existing_files_for_resource(media_dir: Path, resource_name: str) -> list[Path]:
    return [media_dir / f"{resource_name}{ext}" for ext in RESOURCE_EXTENSIONS if (media_dir / f"{resource_name}{ext}").exists()]


def resolve_allowlist() -> tuple[set[str], dict[str, list[str]]]:
    """Return allowed filenames and the media-reference graph used to derive them."""
    pending = sorted(discover_initial_media_refs())
    seen_refs: set[str] = set()
    allowed_files: set[str] = set()
    graph: dict[str, list[str]] = {}

    while pending:
        ref = pending.pop(0)
        if ref in seen_refs:
            continue
        seen_refs.add(ref)
        transitive: set[str] = set()

        for media_dir in MEDIA_DIRS:
            for resource_file in existing_files_for_resource(media_dir, ref):
                allowed_files.add(resource_file.name)
                if resource_file.suffix == ".json":
                    nested = find_media_refs(parse_json_resource(resource_file))
                    transitive.update(nested)

        graph[ref] = sorted(transitive)
        for nested_ref in sorted(transitive):
            if nested_ref not in seen_refs and nested_ref not in pending:
                pending.append(nested_ref)

    return allowed_files, graph


def candidate_files() -> list[Path]:
    files: list[Path] = []
    for media_dir in MEDIA_DIRS:
        if not media_dir.exists():
            continue
        for path in sorted(media_dir.iterdir()):
            if path.is_file() and path.name.startswith(PRUNE_PREFIXES):
                files.append(path)
    return files


def load_manifest() -> dict[str, Any] | None:
    if not MANIFEST_PATH.exists():
        return None
    return json.loads(read_text(MANIFEST_PATH))


def verify_restored(expected_counts: dict[str, int] | None = None) -> dict[str, Any]:
    missing: list[str] = []
    if expected_counts is not None:
        current_counts = {rel(media_dir): len(candidate_files_in(media_dir)) for media_dir in MEDIA_DIRS}
        for media_dir, expected in expected_counts.items():
            if current_counts.get(media_dir) != expected:
                missing.append(f"{media_dir}: expected {expected}, found {current_counts.get(media_dir)}")
    remaining_stash = sorted(rel(path) for path in STASH_DIR.rglob("*") if path.is_file()) if STASH_DIR.exists() else []
    return {"ok": not missing and not remaining_stash, "count_mismatches": missing, "remaining_stash": remaining_stash}


def candidate_files_in(media_dir: Path) -> list[Path]:
    if not media_dir.exists():
        return []
    return [path for path in media_dir.iterdir() if path.is_file() and path.name.startswith(PRUNE_PREFIXES)]


def write_manifest(moved: list[dict[str, str]], allowed_files: set[str], graph: dict[str, list[str]], before_counts: dict[str, int]) -> None:
    ARTIFACT_ROOT.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(
        json.dumps(
            {
                "allowed_files": sorted(allowed_files),
                "reference_graph": graph,
                "before_counts": before_counts,
                "moved": moved,
            },
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )


def apply_prune(dry_run: bool = False) -> int:
    if MANIFEST_PATH.exists() or STASH_DIR.exists():
        raise RuntimeError("release media prune stash already exists; run --restore before --apply")

    allowed_files, graph = resolve_allowlist()
    if not allowed_files:
        raise RuntimeError("media allowlist is empty; refusing to prune")

    candidates = candidate_files()
    to_move = [path for path in candidates if path.name not in allowed_files]
    before_counts = {rel(media_dir): len(candidate_files_in(media_dir)) for media_dir in MEDIA_DIRS}

    print("release media prune allowlist:")
    for name in sorted(allowed_files):
        print(f"  keep {name}")
    print(f"release media prune candidates: {len(candidates)}; pruning: {len(to_move)}")

    if dry_run:
        for path in to_move:
            print(f"  would prune {rel(path)}")
        return 0

    moved: list[dict[str, str]] = []
    STASH_DIR.mkdir(parents=True, exist_ok=True)
    try:
        for path in to_move:
            dest = STASH_DIR / rel(path)
            if dest.exists():
                raise RuntimeError(f"stash destination already exists: {rel(dest)}")
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(dest))
            moved.append({"source": rel(path), "stash": rel(dest)})
            print(f"  pruned {rel(path)}")
        write_manifest(moved, allowed_files, graph, before_counts)
    except Exception:
        # Best-effort rollback so a failed apply does not leave resources missing.
        for item in reversed(moved):
            source = ROOT / item["source"]
            stash = ROOT / item["stash"]
            if stash.exists() and not source.exists():
                source.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(stash), str(source))
        if STASH_DIR.exists() and not any(STASH_DIR.rglob("*")):
            shutil.rmtree(STASH_DIR, ignore_errors=True)
        raise

    print(f"release media prune stashed {len(moved)} files under {rel(STASH_DIR)}")
    return 0


def restore_prune(quiet: bool = False, keep_manifest: bool = False) -> int:
    manifest = load_manifest()
    moved = manifest.get("moved", []) if manifest else []

    restored = 0
    for item in reversed(moved):
        source = ROOT / item["source"]
        stash = ROOT / item["stash"]
        if not stash.exists():
            if source.exists():
                continue
            raise RuntimeError(f"missing stashed resource and source resource: {item['source']}")
        if source.exists():
            raise RuntimeError(f"refusing to overwrite existing source during restore: {item['source']}")
        source.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(stash), str(source))
        restored += 1

    if STASH_DIR.exists():
        shutil.rmtree(STASH_DIR, ignore_errors=True)
    expected_counts = manifest.get("before_counts") if manifest else None
    verification = verify_restored(expected_counts)
    if not verification["ok"]:
        raise RuntimeError("restore verification failed: " + json.dumps(verification, ensure_ascii=False))
    if MANIFEST_PATH.exists() and not keep_manifest:
        MANIFEST_PATH.unlink()
    if not quiet:
        print(f"release media prune restored {restored} files")
        print("restore verification: ok")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Temporarily prune unused release icon/startup media resources")
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--apply", action="store_true", help="move unused icon/startup media resources into the temporary stash")
    action.add_argument("--restore", action="store_true", help="restore resources from the temporary stash")
    action.add_argument("--dry-run", action="store_true", help="print derived allowlist and would-prune list without moving files")
    args = parser.parse_args()

    try:
        if args.apply:
            return apply_prune(dry_run=False)
        if args.dry_run:
            return apply_prune(dry_run=True)
        return restore_prune()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
