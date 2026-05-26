#!/usr/bin/env python3
"""Check i18n resource duplicate groups against the reviewed allowlist.

The project intentionally keeps some equal-value resource keys separate when their
UI/product semantics differ. This contract fails for:
- locale key-set mismatches,
- merged/deleted keys that reappear,
- duplicate value groups not recorded in the reviewed allowlist,
- allowlist entries marked MERGE_SAFE (those must be implemented, not allowed).
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "entry" / "src" / "main" / "resources"
ALLOWLIST_PATH = ROOT / "scripts" / "i18n_duplicate_allowlist.json"
LOCALES = ["base", "en_US", "zh_CN", "zh_HK", "zh_TW"]
ALLOWED_CLASSIFICATIONS = {"KEEP_SEMANTIC", "NEEDS_REVIEW"}


def load_strings(locale: str) -> dict[str, str]:
    path = RESOURCE_ROOT / locale / "element" / "string.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    strings = data.get("string", [])
    names = [item["name"] for item in strings]
    if len(names) != len(set(names)):
        duplicates = sorted({name for name in names if names.count(name) > 1})
        raise AssertionError(f"{locale}: duplicate resource names: {duplicates}")
    return {item["name"]: item["value"] for item in strings}


def duplicate_key_sets(strings: dict[str, str]) -> dict[tuple[str, ...], str]:
    by_value: dict[str, list[str]] = defaultdict(list)
    for name, value in strings.items():
        by_value[value].append(name)
    return {tuple(sorted(names)): value for value, names in by_value.items() if len(names) > 1}


def main() -> int:
    allowlist = json.loads(ALLOWLIST_PATH.read_text(encoding="utf-8"))
    merged_keys = set(allowlist.get("merged_keys", []))
    approved = {}
    errors: list[str] = []

    for group in allowlist.get("approved_duplicate_groups", []):
        keys = tuple(sorted(group.get("keys", [])))
        classification = group.get("classification")
        if classification not in ALLOWED_CLASSIFICATIONS:
            errors.append(
                f"allowlist group {list(keys)} has non-allowable classification {classification}; "
                "MERGE_SAFE groups must be merged instead of allowlisted"
            )
        approved[keys] = group

    locale_strings = {locale: load_strings(locale) for locale in LOCALES}
    base_keys = set(locale_strings["base"].keys())
    for locale, strings in locale_strings.items():
        keys = set(strings.keys())
        if keys != base_keys:
            missing = sorted(base_keys - keys)
            extra = sorted(keys - base_keys)
            errors.append(f"{locale}: key mismatch vs base; missing={missing}, extra={extra}")

        present_merged = sorted(merged_keys & keys)
        if present_merged:
            errors.append(f"{locale}: merged/deleted keys are still present: {present_merged}")

        for key_set, value in duplicate_key_sets(strings).items():
            if key_set not in approved:
                errors.append(
                    f"{locale}: unreviewed duplicate value {value!r} for keys {list(key_set)}"
                )

    if errors:
        print("i18n duplicate contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"i18n duplicate contract passed: {len(approved)} reviewed duplicate key groups, "
        f"{len(merged_keys)} merged/deleted keys guarded across {len(LOCALES)} locales"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
