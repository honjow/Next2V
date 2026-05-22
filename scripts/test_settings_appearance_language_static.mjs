#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const settingsPage = readFileSync('feature/settings/src/main/ets/pages/SettingsPage.ets', 'utf8')
const appStrings = readFileSync('shared/src/main/ets/i18n/AppStrings.ets', 'utf8')
const indexPage = readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
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

assert.match(settingsPage, /@State private languageRefreshKey: number = 0/, 'Settings page needs a language refresh state trigger')
assert.match(settingsPage, /private t\(resource: Resource, fallback: string\): string \{[\s\S]*languageRefreshKey[\s\S]*AppStrings\.t/, 'Settings page localized strings must depend on refresh trigger')
assert.match(settingsPage, /LanguageSettings\.apply\(context, normalizedMode\)[\s\S]*this\.languageRefreshKey = Date\.now\(\)/, 'Language selection must refresh current Settings page copy')
assert.match(indexPage, /@StorageLink\(StorageKeys\.LANGUAGE_MODE\)[\s\S]*@Watch\('onLanguageModeChanged'\)[\s\S]*languageMode: string = ''/, 'Index must observe language mode for title/tab refresh')
assert.match(indexPage, /onLanguageModeChanged\(_propName: string\): void \{[\s\S]*this\.languageRefreshKey = Date\.now\(\)/, 'Index language watcher must update refresh key')
assert.match(indexPage, /IndexRouteCoordinator\.destination\(name, param, this\.languageRefreshKey\)/, 'Destination builder must depend on language refresh key')
assert.match(routeCoordinator, /static destinationTitle\(family: IndexDestinationFamily\): string \{[\s\S]*AppStrings\.t\(AppStrings\.R_NAV_SETTINGS, 'Settings'\)/, 'Destination titles must be computed dynamically after language changes')
assert.doesNotMatch(routeCoordinator, /DESTINATION_TITLES/, 'Destination titles must not be cached in a static localized map')

assert.match(appStrings, /R_SETTINGS_APPEARANCE: Resource = \$r\('app\.string\.settings_appearance'\)/, 'AppStrings must expose settings_appearance')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const resource = JSON.parse(readFileSync(`entry/src/main/resources/${locale}/element/string.json`, 'utf8'))
  const strings = new Map(resource.string.map(item => [item.name, item.value]))
  assert.ok(strings.has('settings_appearance'), `${locale} missing settings_appearance`)
}

const languageMenuItem = settingsPage.slice(indexOfOrFail(settingsPage, '@Builder\n  LanguageModeMenuItem'), indexOfOrFail(settingsPage, '@Builder\n  ThemeModeMenuItem'))
assert.match(languageMenuItem, /MenuItem\(\{\s*content: option\.label\s*\}\)/, 'Language menu must use plain MenuItem labels')
assert.doesNotMatch(languageMenuItem, /SettingsCheckedMenuItem|selected:|✓|✔|☑|✅/, 'Language menu must not show checkmarks')

console.log('test_settings_appearance_language_static: PASS')
