#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const settingsPage = readFileSync('feature/settings/src/main/ets/pages/SettingsPage.ets', 'utf8')
const settingsCoordinator = readFileSync('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets', 'utf8')
const settingsComponents = readFileSync('feature/settings/src/main/ets/components/SettingsPageComponents.ets', 'utf8')
const languageSettings = readFileSync('shared/src/main/ets/settings/LanguageSettings.ets', 'utf8')
const indexPage = readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
const mainTabIcon = readFileSync('entry/src/main/ets/components/MainTabIcon.ets', 'utf8')
const accountCoordinator = readFileSync('entry/src/main/ets/model/AccountPageCoordinator.ets', 'utf8')
const accountPage = readFileSync('entry/src/main/ets/pages/AccountPage.ets', 'utf8')

function indexOfOrFail(text, needle, label = needle) {
  const index = text.indexOf(needle)
  assert.notEqual(index, -1, `${label} not found`)
  return index
}

function assertNoRestartLane(label, text) {
  assert.doesNotMatch(text, /restartApp|terminateSelf|ApplicationContext\.restartApp|LOCALE_REVISION/, `${label} must not use restart/locale revision refresh lane`)
}

const accountHeader = indexOfOrFail(settingsPage, 'this.SectionHeader(AppStrings.R_ACCOUNT_SECTION)', 'account section header')
const appearanceHeader = indexOfOrFail(settingsPage, 'this.SectionHeader(AppStrings.R_SETTINGS_APPEARANCE)', 'appearance section header')
const readingHeader = indexOfOrFail(settingsPage, 'this.SectionHeader(AppStrings.R_SETTINGS_READING)', 'reading section header')
assert.ok(accountHeader < appearanceHeader, 'Appearance group must be after Account group')
assert.ok(appearanceHeader < readingHeader, 'Appearance group must be before Reading group')

assert.match(languageSettings, /import i18n from '@ohos\.i18n'/, 'Language settings must use HarmonyOS i18n System API')
assert.match(languageSettings, /i18n\.System\.setAppPreferredLanguage\(normalized\)/, 'Language changes must set app preferred language')
assert.doesNotMatch(languageSettings, /restartApp|terminateSelf|LOCALE_REVISION/, 'LanguageSettings must not restart or manually refresh locale')
assert.doesNotMatch(settingsPage, /restartApp|terminateSelf|LOCALE_REVISION|languageRefreshKey/, 'SettingsPage must not restart or use manual refresh keys')
assertNoRestartLane('Index', indexPage)

assert.match(settingsCoordinator, /export interface SettingsOption \{\s*label: ResourceStr\s*value: string\s*\}/, 'SettingsOption labels must be ResourceStr')
for (const method of ['themeColorOptions', 'themeModeOptions', 'avatarAppearanceOptions', 'replyDisplayModeOptions', 'replyCardStyleOptions', 'replyActionAlignmentOptions', 'base64DecodeModeOptions']) {
  const start = indexOfOrFail(settingsCoordinator, `static ${method}(`, method)
  const next = settingsCoordinator.indexOf('\n  static ', start + 1)
  const body = settingsCoordinator.slice(start, next === -1 ? undefined : next)
  assert.doesNotMatch(body, /AppStrings\.t\(/, `${method} must return Resource labels, not cached strings`)
  assert.match(body, /label: AppStrings\.R_|ThemeColorSettings\.options\(\)/, `${method} must bind option labels to Resource constants`)
}
for (const method of ['themeColorLabel', 'themeModeLabel', 'languageModeLabel', 'avatarAppearanceLabel', 'replyDisplayModeLabel', 'replyCardStyleLabel', 'replyActionAlignmentLabel', 'base64DecodeModeLabel']) {
  const start = indexOfOrFail(settingsCoordinator, `static ${method}(`, method)
  const next = settingsCoordinator.indexOf('\n  static ', start + 1)
  const body = settingsCoordinator.slice(start, next === -1 ? undefined : next)
  assert.doesNotMatch(body, /AppStrings\.t\(/, `${method} must return ResourceStr labels, not cached strings`)
}

assert.match(settingsComponents, /@Param trailingText: ResourceStr = ''/, 'Settings dropdown row trailing text must accept ResourceStr')
assert.match(settingsComponents, /export struct SettingsThemeColorDropdownRow/, 'Appearance settings must have a theme-color dropdown row')
assert.match(settingsComponents, /export struct SettingsThemeColorDropdownRow[\s\S]+@Param color: ResourceColor/, 'Theme color row must expose a swatch color parameter')
assert.doesNotMatch(settingsComponents, /Text\(AppStrings\.t\(AppStrings\.R_READING_PREVIEW_|title: AppStrings\.t\(AppStrings\.R_RESTORE_DEFAULT|Text\(AppStrings\.t\(AppStrings\.R_TEXT_SCALE/, 'Reading preview, text scale, and restore default must bind Resource constants directly')
assert.match(settingsComponents, /Text\(AppStrings\.R_READING_PREVIEW_TITLE\)/, 'Reading preview title must use Resource')
assert.match(settingsComponents, /Text\(AppStrings\.R_TEXT_SCALE\)/, 'Text scale label must use Resource')
assert.match(settingsComponents, /title: AppStrings\.R_RESTORE_DEFAULT/, 'Restore default row must use Resource')

assert.match(indexPage, /private tabTitles: ResourceStr\[\] = \[\s*AppStrings\.R_SETTINGS_HOME,\s*AppStrings\.R_TAB_DISCOVER,\s*AppStrings\.R_TAB_NOTIFICATIONS,\s*AppStrings\.R_TAB_ME,?\s*\]/, 'Bottom tab title cache must hold ResourceStr constants')
assert.doesNotMatch(indexPage, /TabIcon\(AppStrings\.t\(|tabTitles: string\[\]|this\.tabTitles\[this\.ct\] === AppStrings\.t\(/, 'Bottom tabs/title menus must not compare or bind cached localized strings')
assert.match(mainTabIcon, /@Param title: ResourceStr = ''/, 'MainTabIcon title must accept ResourceStr')

for (const getter of ['SECTION_ACCOUNT', 'SECTION_ACCOUNT_CONTENT', 'SECTION_LOCAL_CONTENT', 'SECTION_MORE', 'LOGIN_TITLE', 'LOGIN_SUBTITLE', 'PROFILE_TITLE', 'LOGOUT_TITLE', 'LOCAL_READ_LATER_TITLE', 'ABOUT_TITLE']) {
  assert.match(accountCoordinator, new RegExp(`static get ${getter}\\(\\): ResourceStr \\{ return AppStrings\\.R_`), `${getter} must return a ResourceStr`)
}
assert.match(accountPage, /SectionHeader\(title: ResourceStr\)/, 'Account section headers must accept ResourceStr')
assert.match(accountPage, /AuthActionRow\(title: ResourceStr, subtitle: ResourceStr/, 'Account action rows must accept ResourceStr labels')
assert.doesNotMatch(accountCoordinator, /static get (SECTION_|LOGIN_|PROFILE_|LOGOUT_|LOCAL_|ABOUT_|ACCOUNT_)[^{]+\{ return AppStrings\.t\(/, 'Account root visible label getters must not return cached strings')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const resource = JSON.parse(readFileSync(`entry/src/main/resources/${locale}/element/string.json`, 'utf8'))
  const names = new Set(resource.string.map(item => item.name))
  for (const key of ['theme_color', 'theme_color_galaxy_blue', 'theme_color_orange_yellow', 'theme_color_cat_blue', 'theme_color_huawei_red', 'theme_color_elegant_purple', 'theme_color_bilibili_pink', 'theme_color_grass_green', 'common_auto', 'common_light', 'common_dark', 'avatar_appearance', 'avatar_appearance_soft', 'avatar_appearance_circle', 'language_follow_system', 'language_simplified_chinese', 'language_traditional_chinese_hk', 'language_traditional_chinese_tw', 'language_english', 'reading_preview_title', 'reading_preview_intro', 'reading_preview_body', 'reading_preview_quote', 'text_scale', 'restore_default']) {
    assert.ok(names.has(key), `${locale} missing ${key}`)
  }
}

const appearanceRowsStart = indexOfOrFail(settingsPage, '@Builder\n  AppearancePreferenceRows()')
const appearanceRowsEnd = settingsPage.indexOf('ReadingPreferenceRows()', appearanceRowsStart + 1)
assert.notEqual(appearanceRowsEnd, -1, 'ReadingPreferenceRows after appearance rows not found')
const appearanceRows = settingsPage.slice(appearanceRowsStart, appearanceRowsEnd)
const themeColorRow = indexOfOrFail(appearanceRows, 'SettingsThemeColorDropdownRow', 'theme color row')
const themeModeRow = indexOfOrFail(appearanceRows, 'title: AppStrings.R_THEME,', 'dark-mode row')
const avatarRow = indexOfOrFail(appearanceRows, 'title: AppStrings.R_AVATAR_APPEARANCE', 'avatar row')
assert.ok(themeColorRow < themeModeRow && themeModeRow < avatarRow, 'Appearance rows must order theme color before dark mode before avatar')

console.log('test_settings_appearance_language_static: PASS')
