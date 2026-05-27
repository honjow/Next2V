#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

const storageKeys = read('shared/src/main/ets/constants/StorageKeys.ets')
const avatarSettings = read('shared/src/main/ets/settings/AvatarAppearanceSettings.ets')
const avatar = read('shared/src/main/ets/components/Avatar.ets')
const bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const settingsCoordinator = read('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets')
const settingsSaveCoordinator = read('feature/settings/src/main/ets/model/SettingsSaveCoordinator.ets')
const backupTypes = read('shared/src/main/ets/backup/BackupTypes.ets')
const backupPreferences = read('shared/src/main/ets/backup/BackupPreferencesAdapter.ets')
const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
const stringMap = read('shared/src/main/ets/i18n/StringMap.ets')

function assertIncludes(text, needle, message) {
  assert.ok(text.includes(needle), message || `missing ${needle}`)
}

function extractMethod(text, name) {
  const start = text.indexOf(`static ${name}(`)
  assert.notEqual(start, -1, `missing static ${name}`)
  const next = text.indexOf('\n  static ', start + 1)
  return text.slice(start, next === -1 ? undefined : next)
}

assertIncludes(storageKeys, "static readonly AVATAR_APPEARANCE: string = 'avatarAppearance'", 'StorageKeys must declare avatarAppearance')

assertIncludes(avatarSettings, "const APPEARANCE_CIRCLE: string = 'circle'", 'circle value must be canonical')
assertIncludes(avatarSettings, "const APPEARANCE_SOFT: string = 'soft'", 'soft value must be canonical')
assertIncludes(avatarSettings, 'readonly defaultValue: string = APPEARANCE_CIRCLE', 'default must preserve current circle behavior')
assertIncludes(avatarSettings, 'StorageKeys.AVATAR_APPEARANCE', 'descriptor must use StorageKeys.AVATAR_APPEARANCE')
assertIncludes(avatarSettings, 'applyDescriptorValue<string>', 'setting must apply normalized descriptor value into AppStorage')
assertIncludes(avatarSettings, 'readDescriptorValue<string>', 'setting must load via descriptor')
assertIncludes(avatarSettings, 'static normalize(appearance: string): string', 'setting must expose normalization')
assert.match(avatarSettings, /if \(value === APPEARANCE_SOFT\) \{\s*return value\s*\}/, 'only soft should opt out of default circle')
assertIncludes(avatarSettings, 'static radiusForSize(avatarSize: number, appearance: string): number', 'setting must centralize radius semantics')
assert.match(avatarSettings, /return Math\.round\(Math\.max\(8, Math\.min\(avatarSize \* 0\.28, avatarSize \/ 2\)\)\)/, 'soft radius must scale with avatar size and cap below circle')

assertIncludes(avatar, '@StorageProp(StorageKeys.AVATAR_APPEARANCE)', 'Avatar must consume global setting directly')
assertIncludes(avatar, 'AvatarAppearanceSettings.radiusForSize(this.avatarSize, this.avatarAppearance)', 'Avatar must use centralized radius helper')
assert.doesNotMatch(avatar, /@Prop\s+appearance|@Prop\s+shape/, 'Avatar should not require per-call shape props')
assert.doesNotMatch(avatar, /borderRadius\(this\.avatarSize \/ 2\)/, 'Avatar must not hard-code circular radius after adding setting')

assertIncludes(bootstrap, 'import { AvatarAppearanceSettings }', 'bootstrap must import avatar appearance settings')
assertIncludes(bootstrap, 'await SettingsBootstrap.restoreAvatarAppearance(context, settingsStore)', 'loadAll must restore avatar appearance')
assertIncludes(bootstrap, 'AvatarAppearanceSettings.apply(AvatarAppearanceSettings.APPEARANCE_CIRCLE)', 'bootstrap fallback must preserve circle default')
assertIncludes(sharedIndex, "export { AvatarAppearanceSettings } from './settings/AvatarAppearanceSettings'", 'shared index must export setting')

assertIncludes(settingsPage, 'AvatarAppearanceSettings', 'settings page must import avatar appearance settings')
assertIncludes(settingsPage, '@StorageLink(StorageKeys.AVATAR_APPEARANCE) avatarAppearance: string =', 'settings page must storage-link avatar appearance')
assertIncludes(settingsPage, 'avatarAppearanceMenuShown', 'settings page must own avatar appearance menu state')
assertIncludes(settingsPage, 'title: AppStrings.R_AVATAR_APPEARANCE', 'settings UI must use selected product title')
assertIncludes(settingsPage, 'SettingsPageCoordinator.avatarAppearanceLabel(this.avatarAppearance)', 'settings row must show selected label')
assertIncludes(settingsPage, 'SettingsPageCoordinator.avatarAppearanceOptions()', 'settings menu must use option helper')
assertIncludes(settingsPage, 'SettingsSaveCoordinator.saveAvatarAppearance', 'settings update must persist through save coordinator')

assertIncludes(settingsCoordinator, 'AvatarAppearanceSettings', 'settings coordinator must import avatar setting')
assertIncludes(settingsCoordinator, 'static avatarAppearanceOptions(): SettingsOption[]', 'settings coordinator must expose avatar options')
const options = extractMethod(settingsCoordinator, 'avatarAppearanceOptions')
assertIncludes(options, 'AppStrings.R_AVATAR_APPEARANCE_SOFT', 'soft option must use resource label')
assertIncludes(options, 'AppStrings.R_AVATAR_APPEARANCE_CIRCLE', 'circle option must use resource label')
assertIncludes(options, 'AvatarAppearanceSettings.APPEARANCE_SOFT', 'soft option must map to soft value')
assertIncludes(options, 'AvatarAppearanceSettings.APPEARANCE_CIRCLE', 'circle option must map to circle value')
const label = extractMethod(settingsCoordinator, 'avatarAppearanceLabel')
assertIncludes(label, 'AppStrings.R_AVATAR_APPEARANCE_SOFT', 'label helper must return soft resource')
assertIncludes(label, 'AppStrings.R_AVATAR_APPEARANCE_CIRCLE', 'label helper must default to circle resource')
assertIncludes(settingsSaveCoordinator, 'static saveAvatarAppearance', 'save coordinator must expose avatar persistence')

assertIncludes(backupTypes, 'appearance?: BackupAppearancePreferences', 'backup preferences must include comparable appearance preferences')
assertIncludes(backupTypes, 'export interface BackupAppearancePreferences', 'backup types must define appearance preferences')
assertIncludes(backupTypes, 'avatarAppearance: string', 'backup appearance section must carry avatarAppearance')
assertIncludes(backupPreferences, 'AvatarAppearanceSettings.load(context)', 'backup export must include avatar appearance setting')
assertIncludes(backupPreferences, 'appearance: { avatarAppearance:', 'backup export must write appearance section')
assertIncludes(backupPreferences, 'AvatarAppearanceSettings.save(context, section.appearance.avatarAppearance ||', 'backup restore must restore avatar appearance')

for (const constant of ['R_AVATAR_APPEARANCE', 'R_AVATAR_APPEARANCE_SOFT', 'R_AVATAR_APPEARANCE_CIRCLE']) {
  assertIncludes(appStrings, constant, `AppStrings missing ${constant}`)
}
for (const [locale, title, soft, circle] of [
  ['en_US', 'Avatar Appearance', 'Soft', 'Circle'],
  ['zh_CN', '头像外观', '圆角', '圆形'],
  ['zh_HK', '頭像外觀', '圓角', '圓形'],
  ['zh_TW', '頭像外觀', '圓角', '圓形'],
]) {
  assertIncludes(stringMap, `'${locale}':`, `StringMap missing ${locale}`)
  assertIncludes(stringMap, `'avatar_appearance': '${title}'`, `${locale} missing avatar_appearance label`)
  assertIncludes(stringMap, `'avatar_appearance_soft': '${soft}'`, `${locale} missing soft label`)
  assertIncludes(stringMap, `'avatar_appearance_circle': '${circle}'`, `${locale} missing circle label`)
}
for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const resource = JSON.parse(read(`entry/src/main/resources/${locale}/element/string.json`))
  const names = new Set(resource.string.map((item) => item.name))
  for (const key of ['avatar_appearance', 'avatar_appearance_soft', 'avatar_appearance_circle']) {
    assert.ok(names.has(key), `${locale} missing ${key}`)
  }
}

console.log('test_avatar_appearance_contract: PASS')
