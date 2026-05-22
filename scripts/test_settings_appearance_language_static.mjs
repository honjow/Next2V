#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const settingsPage = readFileSync('feature/settings/src/main/ets/pages/SettingsPage.ets', 'utf8')
const appStrings = readFileSync('shared/src/main/ets/i18n/AppStrings.ets', 'utf8')
const languageSettings = readFileSync('shared/src/main/ets/settings/LanguageSettings.ets', 'utf8')
const settingsBootstrap = readFileSync('shared/src/main/ets/settings/SettingsBootstrap.ets', 'utf8')
const settingsCoordinator = readFileSync('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets', 'utf8')
const indexPage = readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
const entryAbility = readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8')
const routeCoordinator = readFileSync('entry/src/main/ets/model/IndexRouteCoordinator.ets', 'utf8')

function indexOfOrFail(text, needle, label = needle) {
  const index = text.indexOf(needle)
  assert.notEqual(index, -1, `${label} not found`)
  return index
}

const accountHeader = indexOfOrFail(settingsPage, "this.SectionHeader(this.t(AppStrings.R_ACCOUNT_SECTION, 'Account'))", 'account section header')
const appearanceHeader = indexOfOrFail(settingsPage, "this.SectionHeader(this.t(AppStrings.R_SETTINGS_APPEARANCE, 'Appearance'))", 'appearance section header')
const readingHeader = indexOfOrFail(settingsPage, "this.SectionHeader(this.t(AppStrings.R_SETTINGS_READING, 'Reading'))", 'reading section header')
assert.ok(accountHeader < appearanceHeader, 'Appearance group must be after Account group')
assert.ok(appearanceHeader < readingHeader, 'Appearance group must be before Reading group')

const appearanceStart = indexOfOrFail(settingsPage, '@Builder\n  AppearancePreferenceRows()', 'AppearancePreferenceRows')
const readingStart = indexOfOrFail(settingsPage, '@Builder\n  ReadingPreferenceRows()', 'ReadingPreferenceRows')
const menuStart = indexOfOrFail(settingsPage, '@Builder\n  LanguageModeMenu()', 'LanguageModeMenu')
const appearanceRows = settingsPage.slice(appearanceStart, readingStart)
const readingRows = settingsPage.slice(readingStart, menuStart)
assert.match(appearanceRows, /R_THEME[\s\S]*R_LANGUAGE/, 'Appearance group must contain Theme then Language')
assert.doesNotMatch(readingRows, /R_THEME|R_LANGUAGE/, 'Reading group must not contain Theme or Language')
assert.match(readingRows, /R_REPLY_DISPLAY/, 'Reading group must keep reply display')
assert.match(readingRows, /R_REPLY_STYLE/, 'Reading group must keep reply style')
assert.match(readingRows, /R_REMEMBER_READ_POSITION/, 'Reading group must keep remember reading position')

assert.match(languageSettings, /import i18n from '@ohos\.i18n'/, 'Language settings must use HarmonyOS i18n System API')
assert.match(languageSettings, /i18n\.System\.setAppPreferredLanguage\(language\)/, 'Language changes must set app preferred language')
assert.match(languageSettings, /i18n\.System\.getAppPreferredLanguage\(\)/, 'Language bootstrap must be able to inspect app preferred language')
assert.match(languageSettings, /context\.getApplicationContext\(\)\.setLanguage\(language\)/, 'Language changes should align ApplicationContext language')
assert.match(languageSettings, /context\.getApplicationContext\(\)\.restartApp\(want\)/, 'Language changes must restart EntryAbility')
assert.match(languageSettings, /bundleName: context\.abilityInfo\.bundleName[\s\S]*abilityName: context\.abilityInfo\.name/, 'restartApp must target current EntryAbility')
assert.match(languageSettings, /DEFAULT_APP_LANGUAGE: string = 'default'/, 'Follow-system mode must map to HarmonyOS default app language')
assert.match(languageSettings, /MODE_ZH_CN[\s\S]*'zh-Hans-CN'/, 'Simplified Chinese must map to a valid language ID')
assert.match(languageSettings, /MODE_ZH_HK[\s\S]*'zh-Hant-HK'/, 'Traditional Chinese HK must map to a valid language ID')
assert.match(languageSettings, /MODE_ZH_TW[\s\S]*'zh-Hant-TW'/, 'Traditional Chinese TW must map to a valid language ID')
assert.match(languageSettings, /MODE_EN[\s\S]*'en-US'/, 'English must map to a valid language ID')
assert.match(appStrings, /getOverrideResourceManager\(configuration\)/, 'AppStrings must use override ResourceManager after persisted languageMode bootstrap')
assert.match(appStrings, /resourceLocaleForMode[\s\S]*'zh-Hans-CN'[\s\S]*'zh-Hant-HK'[\s\S]*'zh-Hant-TW'[\s\S]*'en-US'/, 'AppStrings override locales must cover all explicit modes')
assert.match(appStrings, /overrideResourceManager \|\| AppStrings\.context\?\.resourceManager/, 'AppStrings must route all reads through one selected resource source')
assert.match(appStrings, /currentLanguageMode\(\)/, 'AppStrings must expose the active bootstrapped language mode for static contracts')
assert.match(languageSettings, /AppStrings\.applyLanguageMode\(context, normalizedMode\)[\s\S]*setAppStorageValue<AppLanguageMode>\(StorageKeys\.LANGUAGE_MODE, normalizedMode\)/, 'Language bootstrap must initialize AppStrings from persisted languageMode')
assert.match(languageSettings, /restartInProgress/, 'Language restart must guard against duplicate restart taps')
assert.match(settingsPage, /languageRestarting/, 'Settings page must guard duplicate language restart taps')
assert.match(settingsPage, /LanguageSettings\.saveAndRestart\(context, normalizedMode\)/, 'Language selection must save, set system language, and restart')
assert.doesNotMatch(settingsPage, /languageRefreshKey/, 'Settings page must not depend on a local languageRefreshKey patch')
assert.doesNotMatch(indexPage, /languageRefreshKey|onLanguageModeChanged/, 'Index must not use page languageRefreshKey as the language refresh mechanism')
assert.doesNotMatch(routeCoordinator, /_languageRefreshKey|DESTINATION_TITLES/, 'Destination titles must not depend on a manual language refresh key or cached localized map')
assert.match(indexPage, /private tabTitles: string\[\] = \[AppStrings\.t\(AppStrings\.R_SETTINGS_HOME[\s\S]*AppStrings\.R_TAB_DISCOVER[\s\S]*AppStrings\.R_TAB_NOTIFICATIONS[\s\S]*AppStrings\.R_TAB_ME/, 'Tab labels must use AppStrings after bootstrap')
assert.match(routeCoordinator, /destinationTitle\(family: IndexDestinationFamily\)[\s\S]*AppStrings\.t\(AppStrings\.R_NAV_SETTINGS[\s\S]*title: IndexRouteCoordinator\.destinationTitle\(family\)/, 'NavDestination titles must use AppStrings source')
assert.match(settingsPage, /private t\(resource: Resource, fallback: string\): string[\s\S]*AppStrings\.t\(resource, fallback\)/, 'SettingsPage must use the AppStrings source')
assert.match(settingsBootstrap, /restoreLanguage\(context, settingsStore\)[\s\S]*restoreTheme/, 'SettingsBootstrap must restore saved language before other UI settings')
assert.match(entryAbility, /SettingsBootstrap\.loadAll\(this\.context\)\.finally\(\(\) => \{\s*this\.loadContent\(windowStage, win\)/, 'EntryAbility must load UI content only after language bootstrap')
assert.match(settingsBootstrap, /LanguageSettings\.loadFromStore\(settingsStore, context\)/, 'SettingsBootstrap must align saved language mode with system preferred language')

assert.match(appStrings, /R_SETTINGS_APPEARANCE: Resource = \$r\('app\.string\.settings_appearance'\)/, 'AppStrings must expose settings_appearance')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const resource = JSON.parse(readFileSync(`entry/src/main/resources/${locale}/element/string.json`, 'utf8'))
  const strings = new Map(resource.string.map(item => [item.name, item.value]))
  assert.ok(strings.has('settings_appearance'), `${locale} missing settings_appearance`)
}

const languageOptions = settingsCoordinator.slice(indexOfOrFail(settingsCoordinator, 'static languageModeOptions()'), indexOfOrFail(settingsCoordinator, 'static themeModeOptions()'))
for (const mode of ['MODE_SYSTEM', 'MODE_ZH_CN', 'MODE_ZH_HK', 'MODE_ZH_TW', 'MODE_EN']) {
  assert.match(languageOptions, new RegExp(`LanguageSettings\\.${mode}`), `language menu missing ${mode}`)
}
assert.equal((languageOptions.match(/value: LanguageSettings\./g) || []).length, 5, 'Language menu must have exactly five options')
assert.doesNotMatch(languageOptions, /subtitle|description|explain|SettingsCheckedMenuItem|selected:|✓|✔|☑|✅/, 'Language options must not add checkmarks, fake controls, or long explanatory subtitles')

const languageMenuItem = settingsPage.slice(indexOfOrFail(settingsPage, '@Builder\n  LanguageModeMenuItem'), indexOfOrFail(settingsPage, '@Builder\n  ThemeModeMenuItem'))
assert.match(languageMenuItem, /MenuItem\(\{\s*content: option\.label\s*\}\)/, 'Language menu must use plain MenuItem labels')
assert.doesNotMatch(languageMenuItem, /SettingsCheckedMenuItem|selected:|✓|✔|☑|✅/, 'Language menu must not show checkmarks')

console.log('test_settings_appearance_language_static: PASS')
