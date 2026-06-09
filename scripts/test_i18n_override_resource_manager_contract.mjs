#!/usr/bin/env node
import assert from 'node:assert'
import fs from 'node:fs'

const read = (path) => fs.readFileSync(path, 'utf8')
const readEtsFiles = (dir) => {
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  const paths = []
  for (const entry of entries) {
    const path = `${dir}/${entry.name}`
    if (entry.isDirectory()) {
      paths.push(...readEtsFiles(path))
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      paths.push(path)
    }
  }
  return paths
}
const readBusinessEtsFiles = () => [
  ...readEtsFiles('entry/src/main/ets'),
  ...readEtsFiles('feature'),
  ...readEtsFiles('shared/src/main/ets').filter((path) => !path.startsWith('shared/src/main/ets/i18n/')),
]

const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
const languageSettings = read('shared/src/main/ets/settings/LanguageSettings.ets')
const aboutPage = read('entry/src/main/ets/pages/AboutPage.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const settingsPageCoordinator = read('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets')
const settingsPageComponents = read('feature/settings/src/main/ets/components/SettingsPageComponents.ets')
const imageUploadSettingsPage = read('feature/settings/src/main/ets/pages/ImageUploadSettingsPage.ets')
const domainSettingsPage = read('feature/settings/src/main/ets/pages/DomainSettingsPage.ets')
const domainSettingsCoordinator = read('feature/settings/src/main/ets/model/DomainSettingsCoordinator.ets')
const homeNodeSettingsPage = read('feature/settings/src/main/ets/pages/HomeNodeSettingsPage.ets')
const diagnosticsLogPage = read('feature/settings/src/main/ets/pages/DiagnosticsLogPage.ets')
const diagnosticsFileExport = read('shared/src/main/ets/settings/DiagnosticsFileExport.ets')
const cloudSyncSettingsPage = read('feature/settings/src/main/ets/pages/CloudSyncSettingsPage.ets')
const networkProxySettingsPage = read('feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets')
const storageSettingsPage = read('feature/settings/src/main/ets/pages/StorageSettingsPage.ets')
const storageSettingsCoordinator = read('feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets')
const themeColorSettings = read('shared/src/main/ets/settings/ThemeColorSettings.ets')
const networkProxySettings = read('shared/src/main/ets/settings/NetworkProxySettings.ets')
const themeSettings = read('shared/src/main/ets/settings/ThemeSettings.ets')
const avatarAppearanceSettings = read('shared/src/main/ets/settings/AvatarAppearanceSettings.ets')
const replyDisplaySettings = read('shared/src/main/ets/settings/ReplyDisplaySettings.ets')
const replyCardStyleSettings = read('shared/src/main/ets/settings/ReplyCardStyleSettings.ets')
const replyActionAlignmentSettings = read('shared/src/main/ets/settings/ReplyActionAlignmentSettings.ets')
const apiError = read('shared/src/main/ets/network/ApiError.ets')
const accountPageCoordinator = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
const accountPage = read('entry/src/main/ets/pages/AccountPage.ets')
const indexRouteCoordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
const indexTitleBarCoordinator = read('entry/src/main/ets/model/IndexTitleBarCoordinator.ets')
const indexTitleBarComponents = read('entry/src/main/ets/components/IndexTitleBarComponents.ets')
const indexPage = read('entry/src/main/ets/pages/Index.ets')
const staticContracts = read('scripts/static_i18n_contracts.py')

const resourceLocaleDirs = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']
const languageAutonyms = {
  language_simplified_chinese: '简体中文',
  language_traditional_chinese_hk: '繁體中文（香港）',
  language_traditional_chinese_tw: '繁體中文（台灣）',
  language_english: 'English',
  language_japanese: '日本語',
  language_korean: '한국어',
}
const loadStrings = (locale) => Object.fromEntries(JSON.parse(
  read(`entry/src/main/resources/${locale}/element/string.json`),
).string.map((item) => [item.name, item.value]))

const requiredAppStrings = [
  "import { resourceManager } from '@kit.LocalizationKit'",
  'private static overrideResMgr: resourceManager.ResourceManager | null = null',
  'static setOverrideLocaleForLanguageMode(mode: string, resolvedLanguage: string): string',
  'AppStrings.context.resourceManager.getOverrideConfiguration()',
  'config.locale = locale',
  'AppStrings.context.resourceManager.updateOverrideConfiguration(config)',
  'AppStrings.context.resourceManager.getOverrideResourceManager(config)',
  'AppStrings.overrideResMgr.getStringSync(resource.id)',
  "return 'zh-Hans-CN'",
  "return 'zh-Hant-HK'",
  "return 'zh-Hant-TW'",
  "return 'en-US'",
  "return 'ja-JP'",
  "return 'ko-KR'",
]

for (const needle of requiredAppStrings) {
  assert.ok(appStrings.includes(needle), `AppStrings missing override contract: ${needle}`)
}

assert.ok(
  appStrings.indexOf('AppStrings.overrideResMgr.getStringSync(resource.id)') <
    appStrings.indexOf('const resourceSource = AppStrings.context?.resourceManager'),
  'AppStrings.text must prefer override ResourceManager before default ResourceManager',
)

for (const token of [
  "import { STRING_MAP, RESOURCE_BY_NAME } from './StringMap'",
  'STRING_MAP',
  'RESOURCE_BY_NAME',
  'idToName',
  'mapReady',
  'buildIdToNameMap',
  'currentLanguageMode',
  'static readonly R_',
]) {
  assert.ok(!appStrings.includes(token), `AppStrings should not depend on removed i18n compatibility path: ${token}`)
}

assert.ok(
  languageSettings.includes('AppStrings.setOverrideLocaleForLanguageMode(mode, normalized)'),
  'LanguageSettings.apply must hand normalized mode to AppStrings',
)

assert.ok(
  languageSettings.includes('languageState.effectiveLocale = effectiveLocale || normalized'),
  'LanguageSettings.apply must publish effectiveLocale so visible ResourceStr UI hot-refreshes',
)

assert.ok(
  !languageSettings.includes('getOverrideResourceManager'),
  'LanguageSettings must not own ResourceManager override details',
)

assert.ok(
  aboutPage.includes("AppStrings.text($r('app.string.about_tagline'), 'Native HarmonyOS V2EX client')"),
  'AboutPage tagline should use production AppStrings.text path',
)

assert.ok(!appStrings.includes('overrideProbeText'), 'temporary overrideProbeText probe must be removed')

assert.ok(
  staticContracts.includes('required_override_contracts'),
  'static_i18n_contracts should include the override ResourceManager contract',
)

const directLanguageResources = [
  "$r('app.string.language_follow_system')",
  "$r('app.string.language_simplified_chinese')",
  "$r('app.string.language_traditional_chinese_hk')",
  "$r('app.string.language_traditional_chinese_tw')",
  "$r('app.string.language_english')",
  "$r('app.string.language_japanese')",
  "$r('app.string.language_korean')",
]

assert.ok(
  settingsPage.includes("title: $r('app.string.language')"),
  'SettingsPage language row should use direct $r title',
)

for (const needle of directLanguageResources) {
  assert.ok(
    settingsPageCoordinator.includes(needle),
    `SettingsPageCoordinator language labels should use direct resource: ${needle}`,
  )
  assert.ok(
    languageSettings.includes(needle),
    `LanguageSettings.modeText should use direct resource: ${needle}`,
  )
}

for (const locale of resourceLocaleDirs) {
  const strings = loadStrings(locale)
  for (const [key, expected] of Object.entries(languageAutonyms)) {
    assert.equal(
      strings[key],
      expected,
      `${locale} ${key} must stay as language autonym`,
    )
  }
}

for (const [name, source] of [
  ['SettingsPage', settingsPage],
  ['SettingsPageCoordinator', settingsPageCoordinator],
  ['LanguageSettings', languageSettings],
]) {
  assert.ok(!source.includes('AppStrings.R_LANGUAGE'), `${name} should not use AppStrings.R_LANGUAGE_*`)
}

const settingsResourceBatch = [
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

for (const needle of settingsResourceBatch) {
  assert.ok(
    settingsPageCoordinator.includes(needle),
    `SettingsPageCoordinator settings option batch should use direct resource: ${needle}`,
  )
}

for (const needle of [
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
]) {
  assert.ok(
    settingsPage.includes(needle),
    `SettingsPage visible settings row batch should use direct resource: ${needle}`,
  )
}

assert.deepEqual(
  [...settingsPage.matchAll(/AppStrings\.R_[A-Z0-9_]+/g)].map((match) => match[0]),
  [],
  'SettingsPage should no longer depend on AppStrings.R_* constants',
)

for (const needle of [
  "$r('app.string.reading_preview_title')",
  "$r('app.string.reading_preview_intro')",
  "$r('app.string.reading_preview_body')",
  "$r('app.string.reading_preview_quote')",
  "$r('app.string.text_scale')",
  "$r('app.string.restore_default')",
]) {
  assert.ok(
    settingsPageComponents.includes(needle),
    `SettingsPageComponents reading preview batch should use direct resource: ${needle}`,
  )
}

assert.ok(
  !settingsPageCoordinator.includes('AppStrings.R_'),
  'SettingsPageCoordinator should no longer depend on AppStrings.R_* constants',
)

assert.ok(
  !settingsPageComponents.includes('AppStrings.R_'),
  'SettingsPageComponents migrated reading controls should not depend on AppStrings.R_* constants',
)

for (const needle of [
  "$r('app.string.theme_color_galaxy_blue')",
  "$r('app.string.theme_color_orange_yellow')",
  "$r('app.string.theme_color_cat_blue')",
  "$r('app.string.theme_color_huawei_red')",
  "$r('app.string.theme_color_elegant_purple')",
  "$r('app.string.theme_color_bilibili_pink')",
  "$r('app.string.theme_color_grass_green')",
]) {
  assert.ok(
    themeColorSettings.includes(needle),
    `ThemeColorSettings visible theme color label should use direct resource: ${needle}`,
  )
}

assert.ok(
  !themeColorSettings.includes('AppStrings.R_'),
  'ThemeColorSettings should not depend on AppStrings.R_* constants',
)

for (const [name, source, resources] of [
  ['ThemeSettings', themeSettings, [
    "$r('app.string.common_auto')",
    "$r('app.string.common_light')",
    "$r('app.string.common_dark')",
  ]],
  ['AvatarAppearanceSettings', avatarAppearanceSettings, [
    "$r('app.string.avatar_appearance_soft')",
    "$r('app.string.avatar_appearance_circle')",
  ]],
  ['ReplyDisplaySettings', replyDisplaySettings, [
    "$r('app.string.threaded')",
    "$r('app.string.threaded_at')",
    "$r('app.string.threaded_redundant')",
    "$r('app.string.op_only')",
    "$r('app.string.original')",
  ]],
  ['ReplyCardStyleSettings', replyCardStyleSettings, [
    "$r('app.string.density_standard')",
    "$r('app.string.density_compact')",
  ]],
  ['ReplyActionAlignmentSettings', replyActionAlignmentSettings, [
    "$r('app.string.smart_grip')",
    "$r('app.string.follow_operation')",
    "$r('app.string.fixed_left')",
    "$r('app.string.fixed_right')",
  ]],
]) {
  for (const needle of resources) {
    assert.ok(source.includes(needle), `${name} option label should use direct resource: ${needle}`)
  }
  assert.ok(!source.includes('AppStrings.R_'), `${name} should not depend on AppStrings.R_* constants`)
}

for (const needle of [
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
]) {
  assert.ok(
    networkProxySettings.includes(needle),
    `NetworkProxySettings runtime label/summary/validation fallback should use direct resource: ${needle}`,
  )
}

assert.deepEqual(
  [...networkProxySettings.matchAll(/AppStrings\.R_[A-Z0-9_]+/g)].map((match) => match[0]),
  [],
  'NetworkProxySettings should no longer depend on AppStrings.R_* constants',
)

for (const needle of [
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
]) {
  assert.ok(
    imageUploadSettingsPage.includes(needle),
    `ImageUploadSettingsPage visible resource should use direct resource: ${needle}`,
  )
}

assert.deepEqual(
  [...imageUploadSettingsPage.matchAll(/AppStrings\.R_[A-Z0-9_]+/g)].map((match) => match[0]),
  [],
  'ImageUploadSettingsPage should no longer depend on AppStrings.R_* constants',
)

for (const [name, source, resources, allowedAppStrings] of [
  ['DomainSettingsPage', domainSettingsPage, [
    "$r('app.string.api_domain')",
    "$r('app.string.custom_domain')",
    "$r('app.string.domain_validating')",
    "$r('app.string.domain_validate')",
    "$r('app.string.domain_session_hint')",
    "$r('app.string.domain_validate_failed')",
    "$r('app.string.domain_switched')",
    "$r('app.string.common_save_failed')",
  ], []],
  ['HomeNodeSettingsPage', homeNodeSettingsPage, [
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
  ], []],
  ['DiagnosticsLogPage', diagnosticsLogPage, [
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
  ], []],
  ['CloudSyncSettingsPage', cloudSyncSettingsPage, [
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
  ], []],
  ['NetworkProxySettingsPage', networkProxySettingsPage, [
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
  ], [
  ]],
  ['StorageSettingsPage', storageSettingsPage, [
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
  ], []],
]) {
  for (const needle of resources) {
    assert.ok(source.includes(needle), `${name} visible resource should use direct resource: ${needle}`)
  }
  assert.deepEqual(
    [...source.matchAll(/AppStrings\.R_[A-Z0-9_]+/g)].map((match) => match[0]),
    allowedAppStrings,
    `${name} should not depend on AppStrings.R_* constants`,
  )
}

for (const needle of [
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
]) {
  assert.ok(
    storageSettingsCoordinator.includes(needle),
    `StorageSettingsCoordinator runtime resource should use direct resource: ${needle}`,
  )
}

assert.ok(
  !storageSettingsCoordinator.includes('AppStrings.R_'),
  'StorageSettingsCoordinator should no longer depend on AppStrings.R_* constants',
)

for (const needle of [
  "$r('app.string.domain_required')",
  "$r('app.string.domain_invalid')",
  "$r('app.string.domain_https_only')",
  "$r('app.string.domain_validate_http_format')",
  "$r('app.string.domain_not_v2ex')",
  "$r('app.string.domain_requires_verified_session')",
  "$r('app.string.domain_validated')",
  "$r('app.string.domain_network_error')",
  "$r('app.string.domain_validate_failed_format')",
]) {
  assert.ok(
    domainSettingsCoordinator.includes(needle),
    `DomainSettingsCoordinator should use direct resource: ${needle}`,
  )
}

assert.ok(
  !domainSettingsCoordinator.includes('AppStrings.R_'),
  'DomainSettingsCoordinator should no longer depend on AppStrings.R_* constants',
)

assert.ok(
  diagnosticsFileExport.includes("$r('app.string.no_diagnostics_logs')"),
  'DiagnosticsFileExport no-log fallback should use direct resource',
)

assert.ok(
  !diagnosticsFileExport.includes('AppStrings.R_'),
  'DiagnosticsFileExport should no longer depend on AppStrings.R_* constants',
)

for (const path of [
  ...readEtsFiles('feature/settings/src/main/ets'),
  ...readEtsFiles('feature/detail/src/main/ets'),
  ...readEtsFiles('feature/user/src/main/ets'),
  ...readEtsFiles('shared/src/main/ets/settings'),
]) {
  assert.ok(
    !read(path).includes('AppStrings.R_'),
    `${path} should not depend on AppStrings.R_* constants`,
  )
}

const userFeatureText = readEtsFiles('feature/user/src/main/ets')
  .map((path) => read(path))
  .join('\n')
for (const needle of [
  "$r('app.string.user_tab_topics_label')",
  "$r('app.string.user_profile_no_topics')",
  "$r('app.string.user_profile_no_replies')",
  "$r('app.string.user_mark_sheet_title')",
  "$r('app.string.user_mark_display_limit')",
  "$r('app.string.user_profile_member_number')",
]) {
  assert.ok(userFeatureText.includes(needle), `feature/user should use direct resource: ${needle}`)
}

const detailFeatureText = readEtsFiles('feature/detail/src/main/ets')
  .map((path) => read(path))
  .join('\n')
for (const needle of [
  "$r('app.string.reply_body_placeholder')",
  "$r('app.string.jump_to_floor_title')",
  "$r('app.string.topic_detail_loading')",
  "$r('app.string.topic_many_replies_title')",
  "$r('app.string.reply_context_title')",
  "$r('app.string.markdown_placeholder_text')",
  "$r('app.string.reply_count_format')",
]) {
  assert.ok(detailFeatureText.includes(needle), `feature/detail should use direct resource: ${needle}`)
}

for (const needle of [
  "$r('app.string.common_load_failed')",
  "$r('app.string.api_error_auth_required')",
  "$r('app.string.api_error_submit_failed_detail')",
  "$r('app.string.api_error_login_restricted')",
  "$r('app.string.api_error_login_restricted_with_ip')",
  "$r('app.string.api_error_two_factor_failed_detail')",
  "$r('app.string.api_error_token_missing')",
]) {
  assert.ok(
    apiError.includes(needle),
    `ApiError runtime message resource should use direct resource: ${needle}`,
  )
}

assert.ok(
  !apiError.includes('AppStrings.R_'),
  'ApiError should no longer depend on AppStrings.R_* constants',
)

for (const [name, source, resources] of [
  ['AccountPageCoordinator', accountPageCoordinator, [
    "$r('app.string.account_section')",
    "$r('app.string.not_logged_in')",
    "$r('app.string.account_remove_message_arg')",
    "$r('app.string.api_auth_configured')",
    "$r('app.string.daily_checkin')",
    "$r('app.string.daily_checked_in')",
  ]],
  ['AccountPage', accountPage, [
    "$r('app.string.nav_blocked_lists')",
    "$r('app.string.two_factor_required')",
    "$r('app.string.two_factor_relogin_required')",
    "$r('app.string.token_info_failed')",
    "$r('app.string.common_cancel')",
    "$r('app.string.common_clear')",
    "$r('app.string.daily_checkin_reward_toast')",
    "$r('app.string.api_error_checkin_not_available')",
  ]],
]) {
  for (const needle of resources) {
    assert.ok(source.includes(needle), `${name} account resource should use direct resource: ${needle}`)
  }
  assert.ok(!source.includes('AppStrings.R_'), `${name} should no longer depend on AppStrings.R_* constants`)
}

for (const [name, source, resources] of [
  ['IndexRouteCoordinator', indexRouteCoordinator, [
    "$r('app.string.nav_web_login')",
    "$r('app.string.nav_settings')",
    "$r('app.string.nav_all_topics')",
  ]],
  ['IndexTitleBarCoordinator', indexTitleBarCoordinator, [
    "$r('app.string.nav_topic_draft')",
    "$r('app.string.nav_refresh')",
    "$r('app.string.nav_save_image')",
  ]],
  ['IndexTitleBarComponents', indexTitleBarComponents, [
    "$r('app.string.blocked_users')",
    "$r('app.string.ignored_topics')",
    "$r('app.string.nav_search')",
  ]],
  ['IndexPage', indexPage, [
    "$r('app.string.settings_home')",
    "$r('app.string.editor_submit')",
    "$r('app.string.topic_action_unignore_topic')",
    "$r('app.string.user_action_mark')",
    "$r('app.string.web_account_settings')",
  ]],
]) {
  for (const needle of resources) {
    assert.ok(source.includes(needle), `${name} index resource should use direct resource: ${needle}`)
  }
  assert.ok(!source.includes('AppStrings.R_'), `${name} should no longer depend on AppStrings.R_* constants`)
}

for (const path of readBusinessEtsFiles()) {
  assert.ok(
    !read(path).includes('AppStrings.R_'),
    `${path} should not depend on AppStrings.R_* constants`,
  )
}

console.log('i18n override ResourceManager contract: PASS')
