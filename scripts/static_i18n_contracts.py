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
SETTINGS_COMPONENTS = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "components" / "SettingsPageComponents.ets"
IMAGE_UPLOAD_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "ImageUploadSettingsPage.ets"
DOMAIN_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "DomainSettingsPage.ets"
DOMAIN_SETTINGS_COORDINATOR = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "model" / "DomainSettingsCoordinator.ets"
HOME_NODE_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "HomeNodeSettingsPage.ets"
DIAGNOSTICS_LOG_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "DiagnosticsLogPage.ets"
DIAGNOSTICS_FILE_EXPORT = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "DiagnosticsFileExport.ets"
CLOUD_SYNC_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "CloudSyncSettingsPage.ets"
NETWORK_PROXY_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "NetworkProxySettingsPage.ets"
STORAGE_SETTINGS_PAGE = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "pages" / "StorageSettingsPage.ets"
STORAGE_SETTINGS_COORDINATOR = ROOT / "feature" / "settings" / "src" / "main" / "ets" / "model" / "StorageSettingsCoordinator.ets"
LANGUAGE_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "LanguageSettings.ets"
THEME_COLOR_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "ThemeColorSettings.ets"
NETWORK_PROXY_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "NetworkProxySettings.ets"
THEME_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "ThemeSettings.ets"
AVATAR_APPEARANCE_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "AvatarAppearanceSettings.ets"
REPLY_DISPLAY_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "ReplyDisplaySettings.ets"
REPLY_CARD_STYLE_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "ReplyCardStyleSettings.ets"
REPLY_ACTION_ALIGNMENT_SETTINGS = ROOT / "shared" / "src" / "main" / "ets" / "settings" / "ReplyActionAlignmentSettings.ets"
API_ERROR = ROOT / "shared" / "src" / "main" / "ets" / "network" / "ApiError.ets"
ACCOUNT_PAGE_COORDINATOR = ROOT / "entry" / "src" / "main" / "ets" / "model" / "AccountPageCoordinator.ets"
ACCOUNT_PAGE = ROOT / "entry" / "src" / "main" / "ets" / "pages" / "AccountPage.ets"
DISCOVER_PAGE = ROOT / "feature" / "node" / "src" / "main" / "ets" / "pages" / "DiscoverPage.ets"
NOTIFICATION_COMPONENTS = ROOT / "entry" / "src" / "main" / "ets" / "components" / "NotificationPageComponents.ets"
FILTER_CHIP = ROOT / "shared" / "src" / "main" / "ets" / "components" / "FilterChip.ets"
INDEX_ROUTE_COORDINATOR = ROOT / "entry" / "src" / "main" / "ets" / "model" / "IndexRouteCoordinator.ets"
INDEX_TITLE_BAR_COORDINATOR = ROOT / "entry" / "src" / "main" / "ets" / "model" / "IndexTitleBarCoordinator.ets"
INDEX_TITLE_BAR_COMPONENTS = ROOT / "entry" / "src" / "main" / "ets" / "components" / "IndexTitleBarComponents.ets"
INDEX_PAGE = ROOT / "entry" / "src" / "main" / "ets" / "pages" / "Index.ets"

REQUIRED_LOCALE_DIRS = ["base", "en_US", "zh_CN", "zh_HK", "zh_TW", "ja_JP", "ko_KR"]
SUPPORTED_APP_LANGUAGES = ["default", "zh-Hans", "zh-Hant-HK", "zh-Hant-TW", "en-US", "ja-JP", "ko-KR"]

# Paths where CJK is explicitly allowed (V2EX server HTML parsers and server-content matchers).
CJK_ALLOWLIST = [
    "shared/src/main/ets/parser/",
    "shared/src/main/ets/network/V2exNativeAuthService.ets",
    "shared/src/main/ets/services/AutoDailyCheckinService.ets",
    "shared/src/main/ets/settings/CollectionParsers.ets",
    "entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets",
    "entry/src/main/ets/components/DailyCheckinWebRunner.ets",
]

CJK_RE = re.compile(r"[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]")
SKIPPED_SCAN_DIRS = {".git", ".hermes-artifacts", "build", "node_modules", "oh_modules"}

SERVER_PARSE_CJK_TOKENS: dict[str, list[str]] = {
    "shared/src/main/ets/network/ApiService.ets": ["不是你创建的主题"],
}

STICKER_PICKER = "shared/src/main/ets/components/StickerPickerPanel.ets"
STICKER_CODE_RE = re.compile(r"\{\s*name:\s*['\"][^'\"]*[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff][^'\"]*['\"],\s*url:\s*['\"]https://")


def iter_project_ets() -> list[Path]:
    return [
        path
        for path in ROOT.rglob("*.ets")
        if not any(part in SKIPPED_SCAN_DIRS for part in path.relative_to(ROOT).parts)
    ]


def iter_ets_under(relative_dir: str) -> list[Path]:
    root = ROOT / relative_dir
    return sorted(path for path in root.rglob("*.ets") if path.is_file())


def iter_business_ets() -> list[Path]:
    shared_i18n_prefix = ROOT / "shared" / "src" / "main" / "ets" / "i18n"
    return (
        iter_ets_under("entry/src/main/ets")
        + iter_ets_under("feature")
        + [
            path
            for path in iter_ets_under("shared/src/main/ets")
            if shared_i18n_prefix not in path.parents
        ]
    )


def is_comment_line(line: str) -> bool:
    stripped = line.lstrip()
    return stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/**")


def is_server_parse_cjk(rel: str, line: str) -> bool:
    for path, tokens in SERVER_PARSE_CJK_TOKENS.items():
        if rel == path and any(token in line for token in tokens):
            return True
    return False


def is_sticker_code_token(rel: str, line: str) -> bool:
    return rel == STICKER_PICKER and STICKER_CODE_RE.search(line) is not None


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
    """Fail if any user-visible CJK character exists outside resources and narrow protocol/server allowlists."""
    hits: list[str] = []
    for ets_path in sorted(iter_project_ets()):
        rel = str(ets_path.relative_to(ROOT))
        # Skip resource directories
        if "resources" in ets_path.parts:
            continue
        text = ets_path.read_text(encoding="utf-8", errors="ignore")
        for i, line in enumerate(text.splitlines(), 1):
            if not CJK_RE.search(line):
                continue
            if any(rel.startswith(p) for p in CJK_ALLOWLIST):
                continue
            if is_comment_line(line):
                continue
            if is_server_parse_cjk(rel, line):
                continue
            if is_sticker_code_token(rel, line):
                continue
            hits.append(f"  {rel}:{i}: {line.strip()[:100]}")
    if hits:
        raise AssertionError(f"CJK characters found in non-allowlisted source ({len(hits)} lines):\n" + "\n".join(hits[:30]))


def assert_fallback_contract() -> None:
    """Verify language settings contracts: no restart, override handoff, correct key names."""
    text = APP_STRINGS.read_text(encoding="utf-8")
    language_text = LANGUAGE_SETTINGS.read_text(encoding="utf-8")
    entry_text = ENTRY_ABILITY.read_text(encoding="utf-8")
    settings_text = SETTINGS_PAGE.read_text(encoding="utf-8")
    coordinator_text = SETTINGS_COORDINATOR.read_text(encoding="utf-8")
    image_upload_text = IMAGE_UPLOAD_SETTINGS_PAGE.read_text(encoding="utf-8")
    domain_settings_text = DOMAIN_SETTINGS_PAGE.read_text(encoding="utf-8")
    domain_coordinator_text = DOMAIN_SETTINGS_COORDINATOR.read_text(encoding="utf-8")
    home_node_settings_text = HOME_NODE_SETTINGS_PAGE.read_text(encoding="utf-8")
    diagnostics_log_text = DIAGNOSTICS_LOG_PAGE.read_text(encoding="utf-8")
    diagnostics_file_export_text = DIAGNOSTICS_FILE_EXPORT.read_text(encoding="utf-8")
    cloud_sync_settings_text = CLOUD_SYNC_SETTINGS_PAGE.read_text(encoding="utf-8")
    network_proxy_settings_text = NETWORK_PROXY_SETTINGS_PAGE.read_text(encoding="utf-8")
    storage_settings_text = STORAGE_SETTINGS_PAGE.read_text(encoding="utf-8")
    storage_settings_coordinator_text = STORAGE_SETTINGS_COORDINATOR.read_text(encoding="utf-8")
    theme_color_settings_text = THEME_COLOR_SETTINGS.read_text(encoding="utf-8")
    network_proxy_settings_shared_text = NETWORK_PROXY_SETTINGS.read_text(encoding="utf-8")
    theme_settings_text = THEME_SETTINGS.read_text(encoding="utf-8")
    avatar_appearance_settings_text = AVATAR_APPEARANCE_SETTINGS.read_text(encoding="utf-8")
    reply_display_settings_text = REPLY_DISPLAY_SETTINGS.read_text(encoding="utf-8")
    reply_card_style_settings_text = REPLY_CARD_STYLE_SETTINGS.read_text(encoding="utf-8")
    reply_action_alignment_settings_text = REPLY_ACTION_ALIGNMENT_SETTINGS.read_text(encoding="utf-8")
    api_error_text = API_ERROR.read_text(encoding="utf-8")
    account_page_coordinator_text = ACCOUNT_PAGE_COORDINATOR.read_text(encoding="utf-8")
    account_page_text = ACCOUNT_PAGE.read_text(encoding="utf-8")
    discover_page_text = DISCOVER_PAGE.read_text(encoding="utf-8")
    notification_components_text = NOTIFICATION_COMPONENTS.read_text(encoding="utf-8")
    filter_chip_text = FILTER_CHIP.read_text(encoding="utf-8")
    index_route_coordinator_text = INDEX_ROUTE_COORDINATOR.read_text(encoding="utf-8")
    index_title_bar_coordinator_text = INDEX_TITLE_BAR_COORDINATOR.read_text(encoding="utf-8")
    index_title_bar_components_text = INDEX_TITLE_BAR_COMPONENTS.read_text(encoding="utf-8")
    index_page_text = INDEX_PAGE.read_text(encoding="utf-8")
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

    language_autonyms = {
        "language_simplified_chinese": "简体中文",
        "language_traditional_chinese_hk": "繁體中文（香港）",
        "language_traditional_chinese_tw": "繁體中文（台灣）",
        "language_english": "English",
        "language_japanese": "日本語",
        "language_korean": "한국어",
    }
    for locale in REQUIRED_LOCALE_DIRS:
        strings = load_strings(ENTRY_RES, locale)
        for key, expected in language_autonyms.items():
            if strings.get(key) != expected:
                raise AssertionError(f"{locale} {key} must stay as language autonym: {expected}")

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

    if "AppStrings.setOverrideLocaleForLanguageMode(mode, normalized)" not in language_text:
        raise AssertionError("LanguageSettings.apply() must hand explicit language mode to AppStrings")
    if "languageState.effectiveLocale = effectiveLocale || normalized" not in language_text:
        raise AssertionError("LanguageSettings.apply() must publish effective locale for hot UI refresh")

    required_override_contracts = [
        "import { resourceManager } from '@kit.LocalizationKit'",
        "import { connectLanguageState } from '../state/LanguageState'",
        "private static overrideResMgr: resourceManager.ResourceManager | null = null",
        "connectLanguageState().effectiveLocale",
        "static setOverrideLocaleForLanguageMode(mode: string, resolvedLanguage: string): string",
        "AppStrings.context.resourceManager.getOverrideConfiguration()",
        "AppStrings.context.resourceManager.updateOverrideConfiguration(config)",
        "AppStrings.context.resourceManager.getOverrideResourceManager(config)",
        "AppStrings.overrideResMgr.getStringSync(resource.id)",
        "zh-Hans-CN",
        "zh-Hant-HK",
        "zh-Hant-TW",
        "en-US",
        "ja-JP",
        "ko-KR",
    ]
    for needle in required_override_contracts:
        if needle not in text:
            raise AssertionError(f"AppStrings override ResourceManager contract missing: {needle}")

    text_method_start = text.find("static text(resource: Resource, fallback: string): string")
    text_method_end = text.find("static setOverrideLocaleForLanguageMode")
    if text_method_start < 0 or text_method_end < text_method_start:
        raise AssertionError("AppStrings.text method boundary missing")
    text_method = text[text_method_start:text_method_end]
    if "connectLanguageState().effectiveLocale" not in text_method:
        raise AssertionError("AppStrings.text must read LanguageState.effectiveLocale for computed string hot-refresh")

    for needle in [
        "this.TopicModeButton('hot', $r('app.string.discover_hot'), 'Hot')",
        "this.TopicModeButton('latest', $r('app.string.discover_latest'), 'Latest')",
        "this.TopicModeButton('recent', $r('app.string.discover_recent'), 'Recent')",
    ]:
        if needle not in discover_page_text:
            raise AssertionError(f"DiscoverPage topic switch label must pass a Resource and fallback through the chip path: {needle}")

    for needle in [
        "import { AppStrings } from '../i18n/AppStrings'",
        "import { connectLanguageState, LanguageState } from '../state/LanguageState'",
        "@Param label: string",
        "@Param labelResource: Resource",
        "@Param hasLabelResource: boolean",
        "private language: LanguageState = connectLanguageState()",
        "this.language.effectiveLocale.length >= 0",
        "AppStrings.text(this.labelResource, this.label)",
        "text: this.displayLabel()",
    ]:
        if needle not in filter_chip_text:
            raise AssertionError(f"FilterChip must own resource-backed locale refresh: {needle}")

    for needle in [
        "AppStrings.text($r('app.string.notification_kind_mention'), 'Mention')",
        "AppStrings.text($r('app.string.notification_kind_thanks'), 'Thanks')",
    ]:
        if needle not in notification_components_text:
            raise AssertionError(f"Notification kind label must route through AppStrings.text: {needle}")

    if "overrideProbeText" in text:
        raise AssertionError("temporary overrideProbeText device probe must not remain in production AppStrings")

    if "LanguageSettings.applyStoredPreferredLanguage(this.context)" not in entry_text:
        raise AssertionError("EntryAbility.onCreate must re-apply the persisted preferred app language")

    if "LanguageSettings.applyLanguage(context, normalizedMode)" not in settings_text:
        raise AssertionError("SettingsPage must apply language without restarting")

    if "title: $r('app.string.language')" not in settings_text:
        raise AssertionError("SettingsPage language row must use direct $r language resource")

    if "this.t(AppStrings.R_LANGUAGE" in settings_text or "AppStrings.t(AppStrings.R_LANGUAGE" in settings_text:
        raise AssertionError("SettingsPage language row must not use AppStrings.t fallback indirection")

    components_text = SETTINGS_COMPONENTS.read_text(encoding="utf-8")
    if "SettingsCheckedMenuItem" not in settings_text or "sys.symbol.checkmark" not in components_text:
        raise AssertionError("language menu must use checked menu convention")

    required_language_resource_labels = [
        "$r('app.string.language_follow_system')",
        "$r('app.string.language_simplified_chinese')",
        "$r('app.string.language_traditional_chinese_hk')",
        "$r('app.string.language_traditional_chinese_tw')",
        "$r('app.string.language_english')",
        "$r('app.string.language_japanese')",
        "$r('app.string.language_korean')",
    ]
    for label in required_language_resource_labels:
        if label not in coordinator_text:
            raise AssertionError(f"language menu resource label missing from SettingsPageCoordinator: {label}")
        if label not in language_text:
            raise AssertionError(f"language modeText resource label missing from LanguageSettings: {label}")

    for path_name, source_text in [
        ("SettingsPage", settings_text),
        ("SettingsPageCoordinator", coordinator_text),
        ("LanguageSettings", language_text),
    ]:
        if "AppStrings.R_LANGUAGE" in source_text:
            raise AssertionError(f"{path_name} must not depend on AppStrings.R_LANGUAGE_* constants")

    settings_resource_batch = [
        "$r('app.string.common_auto')",
        "$r('app.string.common_light')",
        "$r('app.string.common_dark')",
        "$r('app.string.avatar_appearance_soft')",
        "$r('app.string.avatar_appearance_circle')",
        "$r('app.string.threaded')",
        "$r('app.string.threaded_at')",
        "$r('app.string.threaded_redundant')",
        "$r('app.string.op_only')",
        "$r('app.string.original')",
        "$r('app.string.density_standard')",
        "$r('app.string.density_compact')",
        "$r('app.string.smart_grip')",
        "$r('app.string.follow_operation')",
        "$r('app.string.fixed_left')",
        "$r('app.string.fixed_right')",
        "$r('app.string.common_closed')",
        "$r('app.string.tap_to_view')",
        "$r('app.string.inline_display')",
    ]
    for label in settings_resource_batch:
        if label not in coordinator_text:
            raise AssertionError(f"settings option resource label missing from SettingsPageCoordinator: {label}")

    settings_page_resource_batch = [
        "$r('app.string.account_section')",
        "$r('app.string.settings_appearance')",
        "$r('app.string.settings_reading')",
        "$r('app.string.settings_navigation_actions')",
        "$r('app.string.nav_home_nodes')",
        "$r('app.string.home_tab_auto_hide')",
        "$r('app.string.topic_detail_reply_button_auto_hide')",
        "$r('app.string.settings_content_media')",
        "$r('app.string.nav_storage')",
        "$r('app.string.settings_advanced')",
        "$r('app.string.account_management')",
        "$r('app.string.auto_checkin')",
        "$r('app.string.cloud_sync')",
        "$r('app.string.common_open')",
        "$r('app.string.image_auto_load')",
        "$r('app.string.wifi_only_images')",
        "$r('app.string.image_upload_settings_title')",
        "$r('app.string.image_upload_summary_configured')",
        "$r('app.string.nav_diagnostics')",
        "$r('app.string.api_domain')",
        "$r('app.string.nav_network_proxy')",
        "$r('app.string.theme_color')",
        "$r('app.string.theme')",
        "$r('app.string.avatar_appearance')",
        "$r('app.string.reply_display')",
        "$r('app.string.reply_style')",
        "$r('app.string.reply_action_alignment')",
        "$r('app.string.remember_read_position')",
        "$r('app.string.base64_decode')",
        "$r('app.string.base64_subtitle')",
        "$r('app.string.nav_reading')",
        "$r('app.string.common_save_failed')",
    ]
    for label in settings_page_resource_batch:
        if label not in settings_text:
            raise AssertionError(f"visible settings row resource label missing from SettingsPage: {label}")

    settings_page_appstrings = re.findall(r"AppStrings\.R_[A-Z0-9_]+", settings_text)
    if settings_page_appstrings:
        raise AssertionError(f"SettingsPage must not depend on AppStrings.R_* constants: {settings_page_appstrings}")

    reading_preview_resource_batch = [
        "$r('app.string.reading_preview_title')",
        "$r('app.string.reading_preview_intro')",
        "$r('app.string.reading_preview_body')",
        "$r('app.string.reading_preview_quote')",
        "$r('app.string.text_scale')",
        "$r('app.string.restore_default')",
    ]
    for label in reading_preview_resource_batch:
        if label not in components_text:
            raise AssertionError(f"reading preview resource label missing from SettingsPageComponents: {label}")

    if "AppStrings.R_" in coordinator_text:
        raise AssertionError("SettingsPageCoordinator must not depend on AppStrings.R_* constants")
    if "AppStrings.R_" in components_text:
        raise AssertionError("SettingsPageComponents migrated reading controls must not depend on AppStrings.R_* constants")

    theme_color_resource_batch = [
        "$r('app.string.theme_color_galaxy_blue')",
        "$r('app.string.theme_color_orange_yellow')",
        "$r('app.string.theme_color_cat_blue')",
        "$r('app.string.theme_color_huawei_red')",
        "$r('app.string.theme_color_elegant_purple')",
        "$r('app.string.theme_color_bilibili_pink')",
        "$r('app.string.theme_color_grass_green')",
    ]
    for label in theme_color_resource_batch:
        if label not in theme_color_settings_text:
            raise AssertionError(f"theme color resource label missing from ThemeColorSettings: {label}")
    if "AppStrings.R_" in theme_color_settings_text:
        raise AssertionError("ThemeColorSettings must not depend on AppStrings.R_* constants")

    option_holder_batches = [
        (
            "ThemeSettings",
            theme_settings_text,
            [
                "$r('app.string.common_auto')",
                "$r('app.string.common_light')",
                "$r('app.string.common_dark')",
            ],
        ),
        (
            "AvatarAppearanceSettings",
            avatar_appearance_settings_text,
            [
                "$r('app.string.avatar_appearance_soft')",
                "$r('app.string.avatar_appearance_circle')",
            ],
        ),
        (
            "ReplyDisplaySettings",
            reply_display_settings_text,
            [
                "$r('app.string.threaded')",
                "$r('app.string.threaded_at')",
                "$r('app.string.threaded_redundant')",
                "$r('app.string.op_only')",
                "$r('app.string.original')",
            ],
        ),
        (
            "ReplyCardStyleSettings",
            reply_card_style_settings_text,
            [
                "$r('app.string.density_standard')",
                "$r('app.string.density_compact')",
            ],
        ),
        (
            "ReplyActionAlignmentSettings",
            reply_action_alignment_settings_text,
            [
                "$r('app.string.smart_grip')",
                "$r('app.string.follow_operation')",
                "$r('app.string.fixed_left')",
                "$r('app.string.fixed_right')",
            ],
        ),
    ]
    for holder_name, holder_text, labels in option_holder_batches:
        for label in labels:
            if label not in holder_text:
                raise AssertionError(f"{holder_name} option label resource missing: {label}")
        if "AppStrings.R_" in holder_text:
            raise AssertionError(f"{holder_name} must not depend on AppStrings.R_* constants")

    network_proxy_summary_direct_batch = [
        "$r('app.string.http_proxy')",
        "$r('app.string.socks5_proxy')",
        "$r('app.string.proxy_summary_http')",
        "$r('app.string.proxy_summary_https')",
        "$r('app.string.proxy_summary_socks5')",
        "$r('app.string.proxy_summary_socks5_not_configured')",
        "$r('app.string.proxy_summary_http_not_configured')",
        "$r('app.string.system_proxy')",
        "$r('app.string.common_closed')",
        "$r('app.string.invalid_proxy_host')",
        "$r('app.string.invalid_proxy_port')",
        "$r('app.string.default_proxy_profile_name')",
    ]
    for label in network_proxy_summary_direct_batch:
        if label not in network_proxy_settings_shared_text:
            raise AssertionError(f"network proxy runtime label/summary/validation resource missing from NetworkProxySettings: {label}")
    network_proxy_settings_appstrings = re.findall(r"AppStrings\.R_[A-Z0-9_]+", network_proxy_settings_shared_text)
    if network_proxy_settings_appstrings:
        raise AssertionError(f"NetworkProxySettings must not depend on AppStrings.R_* constants: {network_proxy_settings_appstrings}")

    image_upload_resource_batch = [
        "$r('app.string.image_upload_provider_section')",
        "$r('app.string.image_upload_provider_imgbb')",
        "$r('app.string.image_upload_provider_smms')",
        "$r('app.string.image_upload_imgur_section')",
        "$r('app.string.image_upload_imgbb_hint')",
        "$r('app.string.image_upload_imgbb_apikey_label')",
        "$r('app.string.image_upload_imgbb_apikey_placeholder')",
        "$r('app.string.image_upload_imgbb_get_key')",
        "$r('app.string.image_upload_smms_hint')",
        "$r('app.string.image_upload_smms_token_label')",
        "$r('app.string.image_upload_smms_token_placeholder')",
        "$r('app.string.image_upload_smms_get_token')",
        "$r('app.string.image_upload_imgur_hint')",
        "$r('app.string.image_upload_imgur_clientid_label')",
        "$r('app.string.image_upload_imgur_clientid_placeholder')",
        "$r('app.string.image_upload_summary_configured')",
        "$r('app.string.common_save')",
        "$r('app.string.common_saved')",
        "$r('app.string.common_save_failed')",
        "$r('app.string.proxy_not_configured')",
    ]
    for label in image_upload_resource_batch:
        if label not in image_upload_text:
            raise AssertionError(f"image upload settings resource label missing from ImageUploadSettingsPage: {label}")

    image_upload_appstrings = re.findall(r"AppStrings\.R_[A-Z0-9_]+", image_upload_text)
    if image_upload_appstrings:
        raise AssertionError(f"ImageUploadSettingsPage must not depend on AppStrings.R_* constants: {image_upload_appstrings}")

    settings_subpage_direct_batches = [
        (
            "DomainSettingsPage",
            domain_settings_text,
            [
                "$r('app.string.api_domain')",
                "$r('app.string.custom_domain')",
                "$r('app.string.domain_validating')",
                "$r('app.string.domain_validate')",
                "$r('app.string.domain_session_hint')",
                "$r('app.string.domain_validate_failed')",
                "$r('app.string.domain_switched')",
                "$r('app.string.common_save_failed')",
            ],
            [],
        ),
        (
            "HomeNodeSettingsPage",
            home_node_settings_text,
            [
                "$r('app.string.visible_home_nodes_reorder_hint')",
                "$r('app.string.add_home_column')",
                "$r('app.string.common_reset')",
                "$r('app.string.restore_default')",
                "$r('app.string.common_delete')",
                "$r('app.string.hide')",
                "$r('app.string.node_name_placeholder')",
                "$r('app.string.add_node_column')",
                "$r('app.string.invalid_node_name')",
                "$r('app.string.node_column_exists')",
            ],
            [],
        ),
        (
            "DiagnosticsLogPage",
            diagnostics_log_text,
            [
                "$r('app.string.diagnostics')",
                "$r('app.string.logs')",
                "$r('app.string.log_file')",
                "$r('app.string.nav_diagnostics')",
                "$r('app.string.no_local_log_files')",
                "$r('app.string.clear_boot_records')",
                "$r('app.string.no_log_files')",
                "$r('app.string.reopen_keeps_logs')",
                "$r('app.string.share_file_unavailable_copied')",
                "$r('app.string.share_failed')",
                "$r('app.string.no_diagnostics_logs')",
                "$r('app.string.boot_records_cleared')",
                "$r('app.string.unknown_time')",
            ],
            [],
        ),
        (
            "CloudSyncSettingsPage",
            cloud_sync_settings_text,
            [
                "$r('app.string.cloud_sync_content')",
                "$r('app.string.cloud_sync_open_cloud_space')",
                "$r('app.string.cloud_sync_enable')",
                "$r('app.string.search_history')",
                "$r('app.string.cloud_sync_feat_collections')",
                "$r('app.string.nav_recently_viewed')",
                "$r('app.string.cloud_sync_feat_read_progress')",
                "$r('app.string.cloud_sync_feat_marks')",
                "$r('app.string.cloud_sync_now')",
                "$r('app.string.cloud_sync_syncing')",
                "$r('app.string.cloud_sync_cloud_disabled')",
                "$r('app.string.cloud_sync_last')",
                "$r('app.string.cloud_sync_last_failed')",
            ],
            [],
        ),
        (
            "NetworkProxySettingsPage",
            network_proxy_settings_text,
            [
                "$r('app.string.proxy_config_title')",
                "$r('app.string.proxy_connection')",
                "$r('app.string.use_proxy')",
                "$r('app.string.common_closed')",
                "$r('app.string.system_proxy')",
                "$r('app.string.add_proxy')",
                "$r('app.string.testing_connection')",
                "$r('app.string.test_connection')",
                "$r('app.string.proxy_info')",
                "$r('app.string.proxy_type')",
                "$r('app.string.http_proxy')",
                "$r('app.string.https_proxy_entry')",
                "$r('app.string.socks5_proxy')",
                "$r('app.string.proxy_parameters')",
                "$r('app.string.actions')",
                "$r('app.string.common_save')",
                "$r('app.string.delete_proxy')",
                "$r('app.string.proxy_name_placeholder')",
                "$r('app.string.default_server_port')",
                "$r('app.string.server')",
                "$r('app.string.port')",
                "$r('app.string.username_optional')",
                "$r('app.string.password_optional')",
                "$r('app.string.bypass_list_optional')",
                "$r('app.string.one_domain_or_ip_per_line')",
                "$r('app.string.common_save_failed')",
                "$r('app.string.testing')",
                "$r('app.string.connection_test_success')",
                "$r('app.string.connection_test_failed')",
                "$r('app.string.profile_switched')",
                "$r('app.string.common_saved')",
                "$r('app.string.confirm_delete_proxy_message')",
                "$r('app.string.common_cancel')",
                "$r('app.string.common_delete')",
                "$r('app.string.common_deleted')",
                "$r('app.string.common_delete_failed')",
                "$r('app.string.proxy_profile_not_found')",
                "$r('app.string.switch_failed')",
                "$r('app.string.test_failed')",
            ],
            [],
        ),
        (
            "StorageSettingsPage",
            storage_settings_text,
            [
                "$r('app.string.offline_cache')",
                "$r('app.string.cache_qa_seed')",
                "$r('app.string.account_qa_seed')",
                "$r('app.string.backup_section')",
                "$r('app.string.local_data')",
                "$r('app.string.refresh_cache_status')",
                "$r('app.string.clear_cache')",
                "$r('app.string.export_backup')",
                "$r('app.string.backup_export_subtitle')",
                "$r('app.string.import_backup')",
                "$r('app.string.backup_import_subtitle')",
                "$r('app.string.clear_local_data')",
                "$r('app.string.backup_include_user_info')",
                "$r('app.string.backup_include_user_info_hint')",
                "$r('app.string.backup_set_password')",
                "$r('app.string.backup_password_label')",
                "$r('app.string.backup_password_confirm_label')",
                "$r('app.string.backup_enter_password')",
                "$r('app.string.backup_unlock')",
                "$r('app.string.backup_password_required')",
                "$r('app.string.seed_all_cache_scenarios')",
                "$r('app.string.seed_large_list_file_cache')",
                "$r('app.string.seed_mixed_row_cache')",
                "$r('app.string.seed_invalid_path_row')",
                "$r('app.string.seed_orphan_file')",
                "$r('app.string.seed_missing_file_row')",
                "$r('app.string.seed_hash_mismatch_row')",
                "$r('app.string.verify_hash_repair')",
                "$r('app.string.seed_expired_row')",
                "$r('app.string.reset_seed_cache')",
                "$r('app.string.seed_account_records')",
                "$r('app.string.reset_seeded_accounts')",
            ],
            [],
        ),
    ]
    for page_name, source_text, resource_batch, allowed_appstrings in settings_subpage_direct_batches:
        for label in resource_batch:
            if label not in source_text:
                raise AssertionError(f"settings subpage resource label missing from {page_name}: {label}")
        appstrings = re.findall(r"AppStrings\.R_[A-Z0-9_]+", source_text)
        if appstrings != allowed_appstrings:
            raise AssertionError(f"{page_name} must only keep runtime AppStrings dependencies: {appstrings}")

    storage_coordinator_resources = [
        "$r('app.string.cache_subtitle_updated')",
        "$r('app.string.cache_subtitle')",
        "$r('app.string.clear_cache')",
        "$r('app.string.clear_cache_message')",
        "$r('app.string.common_cancel')",
        "$r('app.string.common_clear')",
        "$r('app.string.clear_local_data')",
        "$r('app.string.clear_local_data_message')",
        "$r('app.string.common_cleared')",
        "$r('app.string.read_cache_status_failed')",
        "$r('app.string.clear_failed')",
        "$r('app.string.debug_only')",
        "$r('app.string.storage_written_format')",
        "$r('app.string.storage_seeded_label_format')",
        "$r('app.string.seed_failed')",
        "$r('app.string.export_backup')",
        "$r('app.string.backup_export_message')",
        "$r('app.string.backup_import_preview_message')",
        "$r('app.string.backup_import_restores_accounts')",
        "$r('app.string.import_backup')",
        "$r('app.string.common_restore')",
        "$r('app.string.backup_import_confirm_message')",
        "$r('app.string.backup_exported')",
        "$r('app.string.backup_import_complete')",
        "$r('app.string.backup_error_foreign')",
        "$r('app.string.backup_error_version')",
        "$r('app.string.backup_error_checksum')",
        "$r('app.string.backup_error_bad_password')",
        "$r('app.string.backup_error_too_large')",
        "$r('app.string.backup_error_invalid')",
        "$r('app.string.backup_password_too_short')",
        "$r('app.string.backup_password_mismatch')",
    ]
    for label in storage_coordinator_resources:
        if label not in storage_settings_coordinator_text:
            raise AssertionError(f"StorageSettingsCoordinator resource label missing: {label}")
    if "AppStrings.R_" in storage_settings_coordinator_text:
        raise AssertionError("StorageSettingsCoordinator must not depend on AppStrings.R_* constants")

    domain_coordinator_resources = [
        "$r('app.string.domain_required')",
        "$r('app.string.domain_invalid')",
        "$r('app.string.domain_https_only')",
        "$r('app.string.domain_validate_http_format')",
        "$r('app.string.domain_not_v2ex')",
        "$r('app.string.domain_requires_verified_session')",
        "$r('app.string.domain_validated')",
        "$r('app.string.domain_network_error')",
        "$r('app.string.domain_validate_failed_format')",
    ]
    for label in domain_coordinator_resources:
        if label not in domain_coordinator_text:
            raise AssertionError(f"DomainSettingsCoordinator resource label missing: {label}")
    if "AppStrings.R_" in domain_coordinator_text:
        raise AssertionError("DomainSettingsCoordinator must not depend on AppStrings.R_* constants")
    if "$r('app.string.no_diagnostics_logs')" not in diagnostics_file_export_text:
        raise AssertionError("DiagnosticsFileExport no-log fallback must use direct resource")
    if "AppStrings.R_" in diagnostics_file_export_text:
        raise AssertionError("DiagnosticsFileExport must not depend on AppStrings.R_* constants")

    for path in (
        iter_ets_under("feature/settings/src/main/ets")
        + iter_ets_under("feature/detail/src/main/ets")
        + iter_ets_under("feature/user/src/main/ets")
        + iter_ets_under("shared/src/main/ets/settings")
    ):
        path_text = path.read_text(encoding="utf-8")
        if "AppStrings.R_" in path_text:
            raise AssertionError(f"{path.relative_to(ROOT)} must not depend on AppStrings.R_* constants")

    user_feature_text = "\n".join(path.read_text(encoding="utf-8") for path in iter_ets_under("feature/user/src/main/ets"))
    user_feature_resources = [
        "$r('app.string.user_tab_topics_label')",
        "$r('app.string.user_profile_no_topics')",
        "$r('app.string.user_profile_no_replies')",
        "$r('app.string.user_mark_sheet_title')",
        "$r('app.string.user_mark_display_limit')",
        "$r('app.string.user_profile_member_number')",
    ]
    for label in user_feature_resources:
        if label not in user_feature_text:
            raise AssertionError(f"feature/user direct resource missing: {label}")

    detail_feature_text = "\n".join(path.read_text(encoding="utf-8") for path in iter_ets_under("feature/detail/src/main/ets"))
    detail_feature_resources = [
        "$r('app.string.reply_body_placeholder')",
        "$r('app.string.jump_to_floor_title')",
        "$r('app.string.topic_detail_loading')",
        "$r('app.string.topic_many_replies_title')",
        "$r('app.string.reply_context_title')",
        "$r('app.string.markdown_placeholder_text')",
        "$r('app.string.reply_count_format')",
    ]
    for label in detail_feature_resources:
        if label not in detail_feature_text:
            raise AssertionError(f"feature/detail direct resource missing: {label}")

    api_error_resources = [
        "$r('app.string.common_load_failed')",
        "$r('app.string.api_error_auth_required')",
        "$r('app.string.api_error_submit_failed_detail')",
        "$r('app.string.api_error_login_restricted')",
        "$r('app.string.api_error_login_restricted_with_ip')",
        "$r('app.string.api_error_two_factor_failed_detail')",
        "$r('app.string.api_error_token_missing')",
    ]
    for label in api_error_resources:
        if label not in api_error_text:
            raise AssertionError(f"ApiError runtime resource missing: {label}")
    if "AppStrings.R_" in api_error_text:
        raise AssertionError("ApiError must not depend on AppStrings.R_* constants")

    account_batches = [
        (
            "AccountPageCoordinator",
            account_page_coordinator_text,
            [
                "$r('app.string.account_section')",
                "$r('app.string.not_logged_in')",
                "$r('app.string.account_remove_message_arg')",
                "$r('app.string.api_auth_configured')",
                "$r('app.string.daily_checkin')",
                "$r('app.string.daily_checked_in')",
            ],
        ),
        (
            "AccountPage",
            account_page_text,
            [
                "$r('app.string.nav_blocked_lists')",
                "$r('app.string.two_factor_required')",
                "$r('app.string.two_factor_relogin_required')",
                "$r('app.string.token_info_failed')",
                "$r('app.string.common_cancel')",
                "$r('app.string.common_clear')",
                "$r('app.string.daily_checkin_reward_toast')",
                "$r('app.string.api_error_checkin_not_available')",
            ],
        ),
    ]
    for source_name, source_text, resources in account_batches:
        for label in resources:
            if label not in source_text:
                raise AssertionError(f"{source_name} account resource missing: {label}")
        if "AppStrings.R_" in source_text:
            raise AssertionError(f"{source_name} must not depend on AppStrings.R_* constants")

    index_batches = [
        (
            "IndexRouteCoordinator",
            index_route_coordinator_text,
            [
                "$r('app.string.nav_web_login')",
                "$r('app.string.nav_settings')",
                "$r('app.string.nav_all_topics')",
            ],
        ),
        (
            "IndexTitleBarCoordinator",
            index_title_bar_coordinator_text,
            [
                "$r('app.string.nav_topic_draft')",
                "$r('app.string.nav_refresh')",
                "$r('app.string.nav_save_image')",
            ],
        ),
        (
            "IndexTitleBarComponents",
            index_title_bar_components_text,
            [
                "$r('app.string.blocked_users')",
                "$r('app.string.ignored_topics')",
                "$r('app.string.nav_search')",
            ],
        ),
        (
            "IndexPage",
            index_page_text,
            [
                "$r('app.string.settings_home')",
                "$r('app.string.editor_submit')",
                "$r('app.string.topic_action_unignore_topic')",
                "$r('app.string.user_action_mark')",
                "$r('app.string.web_account_settings')",
            ],
        ),
    ]
    for source_name, source_text, resources in index_batches:
        for label in resources:
            if label not in source_text:
                raise AssertionError(f"{source_name} index resource missing: {label}")
        if "AppStrings.R_" in source_text:
            raise AssertionError(f"{source_name} must not depend on AppStrings.R_* constants")

    for path in iter_business_ets():
        path_text = path.read_text(encoding="utf-8")
        if "AppStrings.R_" in path_text:
            raise AssertionError(f"{path.relative_to(ROOT)} must not depend on AppStrings.R_* constants")

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


# Keys that leaked Chinese in explicit-English QA (t_62fb0d00).
# These must have CJK-free en_US values in resources so that AppStrings.text()
# returns English when the app language is en-US through override ResourceManager.
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

STRING_MAP_PATH = ROOT / "shared" / "src" / "main" / "ets" / "i18n" / "StringMap.ets"
STRING_MAP_GENERATOR = ROOT / "scripts" / "generate_string_map.py"


def assert_resource_manager_contract() -> None:
    """Verify resource JSON is the source of truth and StringMap is removed."""
    if STRING_MAP_PATH.exists():
        raise AssertionError("StringMap.ets must be removed after ResourceManager migration")
    if STRING_MAP_GENERATOR.exists():
        raise AssertionError("scripts/generate_string_map.py must be removed after ResourceManager migration")

    en_values = load_strings(ENTRY_RES, "en_US")
    for key in LEAKING_KEYS:
        value = en_values.get(key, "")
        if not value.strip():
            raise AssertionError(f"en_US resource empty or missing for leaking key: {key}")
        if CJK_RE.search(value):
            raise AssertionError(f"en_US resource CJK leak in key '{key}': {value[:60]}")

    app_strings_text = APP_STRINGS.read_text(encoding="utf-8")
    forbidden_tokens = [
        "StringMap",
        "STRING_MAP",
        "RESOURCE_BY_NAME",
        "idToName",
        "mapReady",
        "buildIdToNameMap",
        "currentLanguageMode",
        "static readonly R_",
    ]
    for token in forbidden_tokens:
        if token in app_strings_text:
            raise AssertionError(f"AppStrings.ets must not depend on removed i18n compatibility path: {token}")
    for token in [
        "private static overrideResMgr: resourceManager.ResourceManager | null = null",
        "AppStrings.overrideResMgr.getStringSync(resource.id)",
        "AppStrings.context.resourceManager.updateOverrideConfiguration(config)",
        "AppStrings.context.resourceManager.getOverrideResourceManager(config)",
        "resourceSource.getStringSync(resource)",
    ]:
        if token not in app_strings_text:
            raise AssertionError(f"AppStrings ResourceManager contract missing: {token}")


def main() -> int:
    checks = [
        assert_cjk_free,
        assert_resource_sets,
        assert_fallback_contract,
        assert_follow_system_guard,
        assert_resource_manager_contract,
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
