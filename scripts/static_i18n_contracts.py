#!/usr/bin/env python3
"""Strict i18n contracts: CJK-free source, resource parity, and follow-system guard."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY_RES = ROOT / "entry" / "src" / "main" / "resources"
APPSCOPE_RES = ROOT / "AppScope" / "resources"
APP_STRINGS = ROOT / "shared" / "src" / "main" / "ets" / "i18n" / "AppStrings.ets"
ENTRY_ABILITY = ROOT / "entry" / "src" / "main" / "ets" / "entryability" / "EntryAbility.ets"
SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "SettingsPage.ets"
SETTINGS_COORDINATOR = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "model" / "SettingsPageCoordinator.ets"
LANGUAGE_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "LanguageSettings.ets"

REQUIRED_LOCALE_DIRS = ["base", "en_US", "zh_CN", "zh_HK", "zh_TW", "ja_JP", "ko_KR"]
SUPPORTED_APP_LANGUAGES = ["default", "zh-Hans", "zh-Hant-HK", "zh-Hant-TW", "en-US", "ja-JP", "ko-KR"]

# Paths where CJK is explicitly allowed (V2EX server HTML parsers and server-content matchers).
# Everything outside these paths must be CJK-free, including comments.
CJK_ALLOWLIST = [
    "shared/src/main/ets/parser/",
    "shared/src/main/ets/network/V2exNativeAuthService.ets",
    "shared/src/main/ets/services/AutoDailyCheckinService.ets",
    "shared/src/main/ets/settings/CollectionParsers.ets",
    "entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets",
    # Generated locale data, not source code
    "shared/src/main/ets/i18n/StringMap.ets",
]

CJK_RE = re.compile(r"[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]")
SKIPPED_SCAN_DIRS = {".git", ".hermes-artifacts", "build", "node_modules", "oh_modules"}


def iter_project_ets() -> list[Path]:
    return [
        path
        for path in ROOT.rglob("*.ets")
        if not any(part in SKIPPED_SCAN_DIRS for part in path.relative_to(ROOT).parts)
    ]


def load_strings(base: Path, locale: str) -> dict[str, str]:
    path = base / locale / "element" / "string.json"
    if not path.exists():
        raise AssertionError(f"missing resource file: {path.relative_to(ROOT)}")
    data = json.loads(path.read_text(encoding="utf-8"))
    values = data.get("string")
    if not isinstance(values, list):
        raise AssertionError(f"invalid string array: {path.relative_to(ROOT)}")
    result: dict[str, str] = {}
    for item in values:
        name = item.get("name")
        value = item.get("value")
        if not isinstance(name, str) or not isinstance(value, str):
            raise AssertionError(f"invalid string item in {path.relative_to(ROOT)}: {item!r}")
        result[name] = value
    return result


def assert_resource_sets() -> None:
    """Verify resource parity across all locales."""
    entry_sets = {locale: load_strings(ENTRY_RES, locale) for locale in REQUIRED_LOCALE_DIRS}
    base_keys = set(entry_sets["base"].keys())
    if entry_sets["base"].get("app_name") != "Next2V":
        raise AssertionError("base app_name must remain English fallback Next2V")
    for locale, strings in entry_sets.items():
        missing = sorted(base_keys - set(strings.keys()))
        extra = sorted(set(strings.keys()) - base_keys)
        if missing or extra:
            raise AssertionError(f"entry resource keys differ for {locale}: missing={missing[:8]} extra={extra[:8]}")
        empty = sorted(k for k, v in strings.items() if not v.strip())
        if empty:
            raise AssertionError(f"empty strings in {locale}: {empty[:8]}")

    for locale in REQUIRED_LOCALE_DIRS:
        app_scope = load_strings(APPSCOPE_RES, locale)
        if app_scope.get("app_name") != "Next2V":
            raise AssertionError(f"AppScope app_name missing for {locale}")


def assert_cjk_free() -> None:
    """Fail if any CJK character exists outside the allowlist, including in comments."""
    hits: list[str] = []
    for ets_path in sorted(iter_project_ets()):
        rel = str(ets_path.relative_to(ROOT))
        # Skip resource directories
        if "resources" in ets_path.parts:
            continue
        # Skip allowlisted paths
        if any(rel.startswith(p) for p in CJK_ALLOWLIST):
            continue
        text = ets_path.read_text(encoding="utf-8", errors="ignore")
        for i, line in enumerate(text.splitlines(), 1):
            if CJK_RE.search(line):
                hits.append(f"  {rel}:{i}: {line.strip()[:100]}")
    if hits:
        raise AssertionError(f"CJK characters found in non-allowlisted source ({len(hits)} lines):\n" + "\n".join(hits[:30]))


def assert_fallback_contract() -> None:
    """Verify language settings contracts: no restart, no forbidden APIs, correct key names."""
    text = APP_STRINGS.read_text(encoding="utf-8")
    language_text = LANGUAGE_SETTINGS.read_text(encoding="utf-8")
    entry_text = ENTRY_ABILITY.read_text(encoding="utf-8")
    settings_text = SETTINGS_PAGE.read_text(encoding="utf-8")
    coordinator_text = SETTINGS_COORDINATOR.read_text(encoding="utf-8")
    storage_text = (ROOT / "shared" / "src" / "main" / "ets" / "constants" / "StorageKeys.ets").read_text(encoding="utf-8")

    if "LANGUAGE_MODE: string = 'languageMode'" not in storage_text:
        raise AssertionError("language mode storage key must be languageMode")

    for locale in SUPPORTED_APP_LANGUAGES:
        if repr(locale) not in language_text:
            raise AssertionError(f"supported app language missing from LanguageSettings: {locale}")

    required_language_keys = [
        "settings_appearance",
        "language",
        "language_follow_system",
        "language_simplified_chinese",
        "language_traditional_chinese_hk",
        "language_traditional_chinese_tw",
        "language_english",
        "language_japanese",
        "language_korean",
    ]
    for locale in REQUIRED_LOCALE_DIRS:
        strings = load_strings(ENTRY_RES, locale)
        missing = [key for key in required_language_keys if key not in strings]
        if missing:
            raise AssertionError(f"language option resources missing for {locale}: {missing}")

    if load_strings(ENTRY_RES, "base").get("language_follow_system") != "Follow system":
        raise AssertionError("base language default option must be Follow system")

    forbidden_language_settings = [
        "restartApp",
        "terminateSelf",
        "setLanguage(",
        "getOverrideResourceManager",
        "getAppPreferredLanguage",
        "zh-Hans-CN",
    ]
    for needle in forbidden_language_settings:
        if needle in language_text:
            raise AssertionError(f"forbidden language implementation artifact remains: {needle}")

    required_system_contracts = [
        "static async applyLanguage(context: common.UIAbilityContext, areaID: string)",
        "i18n.System.setAppPreferredLanguage(normalized)",
        "store.putSync(KEY_LANGUAGE_MODE, normalized)",
        "store.flushSync()",
        "MODE_SYSTEM: AppLanguageMode = 'default'",
    ]
    for needle in required_system_contracts:
        if needle not in language_text:
            raise AssertionError(f"system language contract missing: {needle}")

    if "LanguageSettings.applyStoredPreferredLanguage(this.context)" not in entry_text:
        raise AssertionError("EntryAbility.onCreate must re-apply the persisted preferred app language")

    if "LanguageSettings.applyLanguage(context, normalizedMode)" not in settings_text:
        raise AssertionError("SettingsPage must apply language without restarting")

    if "title: AppStrings.R_LANGUAGE" not in settings_text:
        raise AssertionError("SettingsPage language row must use a direct resource constant")

    if "this.t(AppStrings.R_LANGUAGE" in settings_text or "AppStrings.t(AppStrings.R_LANGUAGE" in settings_text:
        raise AssertionError("SettingsPage language row must not use AppStrings.t fallback indirection")

    components_path = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "components" / "SettingsPageComponents.ets"
    components_text = components_path.read_text(encoding="utf-8")
    if "SettingsCheckedMenuItem" not in settings_text or "sys.symbol.checkmark" not in components_text:
        raise AssertionError("language menu must use checked menu convention")

    required_language_resource_labels = [
        "AppStrings.R_LANGUAGE_FOLLOW_SYSTEM",
        "AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE",
        "AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK",
        "AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW",
        "AppStrings.R_LANGUAGE_ENGLISH",
        "AppStrings.R_LANGUAGE_JAPANESE",
        "AppStrings.R_LANGUAGE_KOREAN",
    ]
    for label in required_language_resource_labels:
        if label not in coordinator_text:
            raise AssertionError(f"language menu resource label missing: {label}")

    for bad in ["LOCALE_REVISION", "localeRevision", "storageLocaleRevision", "grouped-list-section-${\""]:
        for path in iter_project_ets():
            if bad in path.read_text(encoding="utf-8", errors="ignore"):
                raise AssertionError(f"manual i18n refresh artifact remains: {bad} in {path.relative_to(ROOT)}")


def assert_follow_system_guard() -> None:
    """Verify that reapplyForFollowSystem has the short-circuit guard to prevent infinite loops."""
    text = LANGUAGE_SETTINGS.read_text(encoding="utf-8")
    if "lastAppliedFollowSystemLanguage" not in text:
        raise AssertionError("LanguageSettings must cache last applied follow-system language")
    if "sys === LanguageSettings.lastAppliedFollowSystemLanguage" not in text:
        raise AssertionError("reapplyForFollowSystem must short-circuit when system language unchanged")
    if "LanguageSettings.lastAppliedFollowSystemLanguage = normalized" not in text:
        raise AssertionError("apply() must seed lastAppliedFollowSystemLanguage in follow-system mode")
    if "LanguageSettings.lastAppliedFollowSystemLanguage = sys" not in text:
        raise AssertionError("reapplyForFollowSystem must update lastAppliedFollowSystemLanguage after set")


STRING_MAP_PATH = ROOT / "shared" / "src" / "main" / "ets" / "i18n" / "StringMap.ets"

# Keys that leaked Chinese in explicit-English QA (t_62fb0d00).
# These must have CJK-free en_US values in StringMap so that
# AppStrings.text() returns English when the app language is en-US.
LEAKING_KEYS = [
    # Home/feed
    "topic_last_reply",
    "relative_minutes_ago",
    "relative_hours_ago",
    "relative_days_ago",
    "relative_just_now",
    "topic_replies_count",
    # Discover
    "discover_hot",
    "discover_rank",
    "discover_latest",
    "discover_recent",
    "discover_today_hot",
    "common_nodes",
    "discover_section_recent_nodes",
    "discover_section_saved_nodes",
    "discover_site_rank",
    "discover_latest_topics",
    "discover_recent_updates",
    # Topic detail
    "topic_detail_tool_floor",
    "topic_detail_tool_latest",
    "reply_count_format",
    "threaded",
    "threaded_at",
    "threaded_redundant",
    "reply_thread_relation_label_format",
    # Local followed nodes
    "empty_no_local_followed_nodes",
    # About
    "about_version_format",
    # Relative time (remaining)
    "relative_months_ago",
    "relative_years_ago",
]


def assert_string_map_contract() -> None:
    """Verify that the generated StringMap provides correct English values
    for all leaking keys, and that en_US values are CJK-free."""
    if not STRING_MAP_PATH.exists():
        raise AssertionError("StringMap.ets is missing")
    text = STRING_MAP_PATH.read_text(encoding="utf-8")

    # All locales should have entries
    for locale in ["en_US", "zh_CN", "zh_HK", "zh_TW", "ja_JP", "ko_KR"]:
        if f"'{locale}':" not in text:
            raise AssertionError(f"StringMap.ets missing locale {locale}")

    # Extract en_US values for the leaking keys and verify CJK-free.
    # The block structure has each locale key followed by its object literal
    # and a closing "  }," line before the next locale.
    pat = re.compile(r"'en_US':\s*\{(.*?)\n  \},", re.DOTALL)
    m = pat.search(text)
    if not m:
        raise AssertionError("StringMap.ets en_US block not found")
    en_block = m.group(1)

    for key in LEAKING_KEYS:
        key_pat = re.compile(rf"'{key}':\s*'((?:[^'\\]|\\.)*)'")
        km = key_pat.search(en_block)
        if not km:
            raise AssertionError(f"StringMap.ets en_US missing key: {key}")
        value = km.group(1)
        if not value.strip():
            raise AssertionError(f"StringMap.ets en_US empty value for: {key}")
        if CJK_RE.search(value):
            raise AssertionError(
                f"StringMap.ets en_US CJK leak in key '{key}': {value[:60]}"
            )
        # Verify the value does not contain { and } if it's not a template
        # (template keys are expected to have {0} etc.)

    # Verify key count parity with resource files
    resource_count = len(load_strings(ENTRY_RES, "en_US"))
    string_map_en_count = len(re.findall(r"'(\w+)':\s*'", en_block))
    if string_map_en_count != resource_count:
        raise AssertionError(
            f"StringMap.ets en_US has {string_map_en_count} keys, "
            f"but resources have {resource_count}"
        )

    # Verify AppStrings.ets uses the StringMap
    app_strings_text = APP_STRINGS.read_text(encoding="utf-8")
    if "import { STRING_MAP, RESOURCE_BY_NAME } from './StringMap'" not in app_strings_text:
        raise AssertionError("AppStrings.ets must import STRING_MAP and RESOURCE_BY_NAME")
    if "AppStrings.idToName.set" not in app_strings_text:
        raise AssertionError("AppStrings.ets must build ID→name map from RESOURCE_BY_NAME")
    if "STRING_MAP[localeKey]" not in app_strings_text:
        raise AssertionError("AppStrings.text() must resolve strings from STRING_MAP")


def main() -> int:
    checks = [
        assert_cjk_free,
        assert_resource_sets,
        assert_fallback_contract,
        assert_follow_system_guard,
        assert_string_map_contract,
    ]
    for check in checks:
        check()
    print("static_i18n_contracts: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"static_i18n_contracts: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
