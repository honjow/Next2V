#!/usr/bin/env python3
"""Static i18n contracts for the first V2Next localization migration."""
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

# Harmony/OpenHarmony resource qualifier directories observed/validated by build for this worktree.
# base is English fallback. Specific locale resources use underscore directory names.
REQUIRED_LOCALE_DIRS = ["base", "en_US", "zh_CN", "zh_HK", "zh_TW"]
SUPPORTED_APP_LANGUAGES = ["default", "zh-Hans", "zh-Hant-HK", "zh-Hant-TW", "en-US"]

KEY_TERMS = {
    "feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets": [
        "代理连接", "使用代理", "系统代理", "添加代理", "正在测试连接…", "测试连接",
        "代理信息", "代理类型", "HTTP 代理", "SOCKS5 代理", "代理参数", "绕过列表（可选）",
        "SOCKS5 暂不支持用户名/密码认证", "已切换配置", "测试失败",
    ],
    "feature/settings/src/main/ets/pages/SettingsPage.ets": [
        "账号", "界面", "阅读", "首页栏目设置", "内容与媒体", "存储", "高级", "网络代理",
        "主题", "语言", "回复显示", "回复样式", "记住阅读位置", "Base64 解码",
    ],
    "entry/src/main/ets/model/IndexRouteCoordinator.ets": [
        "网页登录", "账号密码登录", "关注用户", "设置", "网络代理", "全部回复",
    ],
    "entry/src/main/ets/pages/AccountFollowingPage.ets": [
        "登录后可查看关注用户", "关注用户", "暂无关注用户",
    ],
}


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


def assert_fallback_contract() -> None:
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
        raise AssertionError("SettingsPage language row must use a direct resource constant, not AppStrings.t fallback indirection")
    if "this.t(AppStrings.R_LANGUAGE" in settings_text or "AppStrings.t(AppStrings.R_LANGUAGE" in settings_text:
        raise AssertionError("SettingsPage language row must not use AppStrings.t fallback indirection")
    if "SettingsCheckedMenuItem" not in settings_text or "sys.symbol.checkmark" not in (ROOT / "feature" / "settings" / "src" / "main" / "ets" / "components" / "SettingsPageComponents.ets").read_text(encoding="utf-8"):
        raise AssertionError("language menu must use checked menu convention")
    required_language_resource_labels = [
        "AppStrings.R_LANGUAGE_FOLLOW_SYSTEM",
        "AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE",
        "AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK",
        "AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW",
        "AppStrings.R_LANGUAGE_ENGLISH",
    ]
    for label in required_language_resource_labels:
        if label not in coordinator_text:
            raise AssertionError(f"language menu resource label missing: {label}")
    for bad in ["LOCALE_REVISION", "localeRevision", "storageLocaleRevision", "grouped-list-section-${"]:
        for path in ROOT.rglob("*.ets"):
            if bad in path.read_text(encoding="utf-8", errors="ignore"):
                raise AssertionError(f"manual i18n refresh artifact remains: {bad} in {path.relative_to(ROOT)}")


def assert_key_terms_migrated() -> None:
    for rel, terms in KEY_TERMS.items():
        text = (ROOT / rel).read_text(encoding="utf-8")
        for term in terms:
            raw_single = f"'{term}'"
            raw_double = f'"{term}"'
            if raw_single in text or raw_double in text:
                # Allow only resource fallback arguments inside AppStrings.t(..., 'term'), not raw direct UI literals.
                direct_literals = []
                for line in text.splitlines():
                    if raw_single in line or raw_double in line:
                        if "AppStrings.t(AppStrings." not in line:
                            direct_literals.append(line.strip())
                if direct_literals:
                    raise AssertionError(f"unmapped hard-coded UI string in {rel}: {term}: {direct_literals[:2]}")
            if term in text and "AppStrings.t" not in text and "AppStrings.R_" not in text:
                raise AssertionError(f"file contains key term but no resource mapping: {rel}: {term}")


def main() -> int:
    checks = [assert_resource_sets, assert_fallback_contract, assert_key_terms_migrated]
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
