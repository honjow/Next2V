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

function assertIncludes(text, needle, message) {
  assert.ok(text.includes(needle), message || `missing ${needle}`)
}

// Mirror BackupSecretDenylist.isExcluded so we can assert avatarAppearance survives the whole-store
// dump. Markers are parsed straight from the denylist source to stay faithful if the list changes.
const denylistSource = read('shared/src/main/ets/backup/BackupSecretDenylist.ets')
const sensitiveSubstrings = [...denylistSource.matchAll(/'([a-z]+)',/g)]
  .map((m) => m[1])
  .filter((s) => ['password', 'secret', 'token', 'cookie', 'proxy', 'credential'].includes(s))
const transientKeys = [...denylistSource.matchAll(/'(autoDailyCheckin[A-Za-z]+)'/g)].map((m) => m[1])
function BackupSecretDenylistExcludes(key) {
  const lower = key.toLowerCase()
  if (sensitiveSubstrings.some((frag) => lower.includes(frag))) {
    return true
  }
  return transientKeys.includes(key)
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
assertIncludes(avatarSettings, 'readonly defaultValue: string = APPEARANCE_SOFT', 'default must preserve current soft behavior')
assertIncludes(avatarSettings, 'StorageKeys.AVATAR_APPEARANCE', 'descriptor must use StorageKeys.AVATAR_APPEARANCE')
assertIncludes(avatarSettings, 'applyDescriptorValue<string>', 'setting must apply normalized descriptor value into AppStorage')
assertIncludes(avatarSettings, 'readDescriptorValue<string>', 'setting must load via descriptor')
assertIncludes(avatarSettings, 'static normalize(appearance: string): string', 'setting must expose normalization')
assert.match(avatarSettings, /if \(value === APPEARANCE_CIRCLE\) \{\s*return value\s*\}/, 'only circle should opt out of default soft')
assertIncludes(avatarSettings, 'static radiusForSize(avatarSize: number, appearance: string): number', 'setting must centralize radius semantics')
assert.match(avatarSettings, /return Math\.round\(Math\.max\(8, Math\.min\(avatarSize \* 0\.28, avatarSize \/ 2\)\)\)/, 'soft radius must scale with avatar size and cap below circle')

assertIncludes(avatar, 'connectAvatarAppearance()', 'Avatar must consume global setting through V2 holder')
assertIncludes(avatar, 'AvatarAppearanceSettings.radiusForSize(this.avatarSize, this.appearanceState.appearance)', 'Avatar must use centralized radius helper')
assert.doesNotMatch(avatar, /@Prop\s+appearance|@Prop\s+shape/, 'Avatar should not require per-call shape props')
assert.doesNotMatch(avatar, /borderRadius\(this\.avatarSize \/ 2\)/, 'Avatar must not hard-code circular radius after adding setting')

assertIncludes(bootstrap, 'import { AvatarAppearanceSettings }', 'bootstrap must import avatar appearance settings')
assertIncludes(bootstrap, 'await SettingsBootstrap.restoreAvatarAppearance(context, settingsStore)', 'loadAll must restore avatar appearance')
assertIncludes(bootstrap, 'AvatarAppearanceSettings.apply(AvatarAppearanceSettings.APPEARANCE_SOFT)', 'bootstrap fallback must preserve soft default')
assertIncludes(sharedIndex, "export { AvatarAppearanceSettings } from './settings/AvatarAppearanceSettings'", 'shared index must export setting')

assertIncludes(settingsPage, 'AvatarAppearanceSettings', 'settings page must import avatar appearance settings')
assertIncludes(settingsPage, 'private avatar: AvatarAppearanceState = connectAvatarAppearance()', 'settings page must consume avatar appearance through V2 holder')
assertIncludes(settingsPage, 'avatarAppearanceMenuShown', 'settings page must own avatar appearance menu state')
assertIncludes(settingsPage, "title: $r('app.string.avatar_appearance')", 'settings UI must use selected product title')
assertIncludes(settingsPage, 'SettingsPageCoordinator.avatarAppearanceLabel(this.avatar.appearance)', 'settings row must show selected label')
assertIncludes(settingsPage, 'SettingsPageCoordinator.avatarAppearanceOptions()', 'settings menu must use option helper')
assertIncludes(settingsPage, 'SettingsSaveCoordinator.saveAvatarAppearance', 'settings update must persist through save coordinator')

assertIncludes(settingsCoordinator, 'AvatarAppearanceSettings', 'settings coordinator must import avatar setting')
assertIncludes(settingsCoordinator, 'static avatarAppearanceOptions(): SettingsOption[]', 'settings coordinator must expose avatar options')
const options = extractMethod(settingsCoordinator, 'avatarAppearanceOptions')
assertIncludes(options, "$r('app.string.avatar_appearance_soft')", 'soft option must use resource label')
assertIncludes(options, "$r('app.string.avatar_appearance_circle')", 'circle option must use resource label')
assertIncludes(options, 'AvatarAppearanceSettings.APPEARANCE_SOFT', 'soft option must map to soft value')
assertIncludes(options, 'AvatarAppearanceSettings.APPEARANCE_CIRCLE', 'circle option must map to circle value')
const label = extractMethod(settingsCoordinator, 'avatarAppearanceLabel')
assertIncludes(label, "$r('app.string.avatar_appearance_soft')", 'label helper must return soft resource')
assertIncludes(label, "$r('app.string.avatar_appearance_circle')", 'label helper must default to circle resource')
assertIncludes(settingsSaveCoordinator, 'static saveAvatarAppearance', 'save coordinator must expose avatar persistence')

assertIncludes(backupTypes, 'appearance?: BackupAppearancePreferences', 'backup preferences must include comparable appearance preferences')
assertIncludes(backupTypes, 'export interface BackupAppearancePreferences', 'backup types must define appearance preferences')
assertIncludes(backupTypes, 'avatarAppearance: string', 'backup appearance section must carry avatarAppearance')
// Backup export was refactored from per-setting reads to a whole-store dump of next2v_settings
// (dumpSettingsStore, minus the secret/transient denylist). avatarAppearance lives in that store, so
// it is captured automatically; the per-setting AvatarAppearanceSettings.load() export call is retired.
// The contract intent (avatar appearance IS backed up) now holds iff the dump path exists AND
// avatarAppearance is not denylisted.
assertIncludes(backupPreferences, 'dumpSettingsStore', 'backup export must dump the unified settings store (captures avatarAppearance automatically)')
assert.ok(!BackupSecretDenylistExcludes('avatarAppearance'), 'avatarAppearance must NOT be denylisted, so the whole-store dump backs it up')
// New backups restore via the whole-store write-back; old (legacy typed) backups restore via the
// per-setting save path, which must still target avatarAppearance.
assert.match(backupPreferences, /AvatarAppearanceSettings\.save\(\s*context,/, 'backup restore (legacy typed path) must restore avatar appearance')
assertIncludes(backupPreferences, 'section.appearance.avatarAppearance ||', 'legacy restore must read avatarAppearance from the appearance section')

// i18n migration: the AppStrings.R_AVATAR_APPEARANCE* constants were retired; AppStrings.ets is now a
// ResourceManager resolver. The avatar-appearance labels are consumed directly via $r('app.string.KEY')
// from the settings page + coordinator (also pinned individually above).
for (const ref of [
  "$r('app.string.avatar_appearance')",
  "$r('app.string.avatar_appearance_soft')",
  "$r('app.string.avatar_appearance_circle')",
]) {
  assert.ok(
    settingsPage.includes(ref) || settingsCoordinator.includes(ref),
    `avatar-appearance label must be referenced via ${ref}`,
  )
}
for (const [locale, title, soft, circle] of [
  ['en_US', 'Avatar appearance', 'Soft', 'Circle'],
  ['zh_CN', '头像外观', '圆角', '圆形'],
  ['zh_HK', '頭像外觀', '圓角', '圓形'],
  ['zh_TW', '頭像外觀', '圓角', '圓形'],
]) {
  const resource = JSON.parse(read(`entry/src/main/resources/${locale}/element/string.json`))
  const values = new Map(resource.string.map((item) => [item.name, item.value]))
  assert.equal(values.get('avatar_appearance'), title, `${locale} avatar_appearance label mismatch`)
  assert.equal(values.get('avatar_appearance_soft'), soft, `${locale} soft label mismatch`)
  assert.equal(values.get('avatar_appearance_circle'), circle, `${locale} circle label mismatch`)
}
for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const resource = JSON.parse(read(`entry/src/main/resources/${locale}/element/string.json`))
  const names = new Set(resource.string.map((item) => item.name))
  for (const key of ['avatar_appearance', 'avatar_appearance_soft', 'avatar_appearance_circle']) {
    assert.ok(names.has(key), `${locale} missing ${key}`)
  }
}

console.log('test_avatar_appearance_contract: PASS')
