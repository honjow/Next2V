#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (p) => fs.readFileSync(path.join(repo, p), 'utf8')

const storage = read('shared/src/main/ets/constants/StorageKeys.ets')
const settings = read('shared/src/main/ets/settings/AutoDailyCheckinSettings.ets')
const service = read('shared/src/main/ets/services/AutoDailyCheckinService.ets')
const index = read('shared/src/main/ets/Index.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
const nativeLogin = read('entry/src/main/ets/pages/V2exNativeLoginPage.ets')
const webLogin = read('entry/src/main/ets/pages/V2exWebLoginPage.ets')
const twoFactor = read('entry/src/main/ets/components/V2exTwoFactorPrompt.ets')
const api = read('shared/src/main/ets/network/ApiService.ets')
const parser = read('shared/src/main/ets/parser/V2exAccountParser.ets')

assert.match(storage, /AUTO_DAILY_CHECKIN_ENABLED:\s*string\s*=\s*'autoDailyCheckinEnabled'/, 'StorageKeys must expose auto daily check-in setting key')
assert.match(storage, /AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE:\s*string\s*=\s*'autoDailyCheckinLastAttemptDate'/, 'StorageKeys must expose last attempt key')
assert.match(storage, /AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY:\s*string\s*=\s*'autoDailyCheckinLastAttemptIdentity'/, 'StorageKeys must expose last attempt identity key')
assert.match(storage, /AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE:\s*string\s*=\s*'autoDailyCheckinLastSuccessDate'/, 'StorageKeys must expose last success key')
assert.match(settings, /const STORE_NAME:\s*string\s*=\s*STORE_NAME_SETTINGS/, 'helper must use existing settings preference store')
assert.match(settings, /const KEY_ENABLED:\s*string\s*=\s*StorageKeys\.AUTO_DAILY_CHECKIN_ENABLED/, 'helper must persist with the AppStorage key name')
assert.match(settings, /store\.getSync\(KEY_ENABLED,\s*true\)/, 'setting must default to true when absent')
assert.match(settings, /setAppStorageValue<boolean>\(StorageKeys\.AUTO_DAILY_CHECKIN_ENABLED,\s*enabled\)/, 'helper must mirror enabled into AppStorage')
assert.match(settings, /KEY_LAST_ATTEMPT_IDENTITY:\s*string\s*=\s*StorageKeys\.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY/, 'helper must persist a non-cookie attempt identity')
assert.match(settings, /setAppStorageValue<string>\(StorageKeys\.AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY,\s*lastAttemptIdentity\s*\|\|\s*''\)/, 'helper must mirror last attempt identity into AppStorage')
assert.match(settings, /saveLastAttemptDate\(\s*context:\s*common\.UIAbilityContext,\s*localDate:\s*string,\s*lastAttemptIdentity:\s*string,?\s*\)/, 'attempt persistence must include identity')
assert.match(settings, /store\.putSync\(KEY_LAST_ATTEMPT_IDENTITY,\s*lastAttemptIdentity\)/, 'attempt identity must be persisted')
assert.match(index, /AutoDailyCheckinSettings/, 'shared barrel must export the settings helper')
assert.match(index, /AutoDailyCheckinService/, 'shared barrel must export the auto check-in service')

const accountSectionStart = settingsPage.indexOf('@Builder\n  AccountSection()')
const readingSectionStart = settingsPage.indexOf('@Builder\n  ReadingSection()', accountSectionStart)
assert.ok(accountSectionStart >= 0 && readingSectionStart > accountSectionStart, 'SettingsPage account section boundaries must be found')
const accountSection = settingsPage.slice(accountSectionStart, readingSectionStart)
assert.match(settingsPage, /@StorageLink\(StorageKeys\.AUTO_DAILY_CHECKIN_ENABLED\)\s+autoDailyCheckinEnabled:\s*boolean\s*=\s*true/, 'SettingsPage must bind switch state to the new AppStorage key')
assert.match(accountSection, /TogglePreferenceRow\('自动签到',\s*this\.autoDailyCheckinEnabled/, 'account section must show 自动签到 as a switch row')
assert.doesNotMatch(accountSection, /Button\('自动签到'|FilterChip\(|Chip\(/, 'auto daily check-in must not be implemented as button/chip')
assert.match(settingsPage, /SettingsSaveCoordinator\.saveAutoDailyCheckin\(context,\s*enabled\)/, 'switch updates must persist via helper')

assert.match(service, /if\s*\(!AutoDailyCheckinSettings\.isEnabled\(\)\)\s*{[\s\S]*?'disabled'/, 'service must skip when disabled')
assert.match(service, /if\s*\(!cleanCookie\)\s*{[\s\S]*?'no-cookie'/, 'service must skip without cookie')
assert.match(service, /if\s*\(AutoDailyCheckinService\.inFlight\)\s*{[\s\S]*?'in-flight'/, 'service must guard concurrent runs')
assert.match(service, /const\s+attemptIdentity\s*=\s*AutoDailyCheckinService\.cookieAttemptIdentity\(cleanCookie\)/, 'service must derive a non-cookie identity for the current cookie')
assert.match(service, /getLastAttemptDate\(\)\s*===\s*today\s*&&\s*\n\s*AutoDailyCheckinSettings\.getLastAttemptIdentity\(\)\s*===\s*attemptIdentity[\s\S]*?'already-attempted'/, 'service must skip same local day only for the same cookie identity')
assert.match(service, /saveLastAttemptDate\(context,\s*today,\s*attemptIdentity\)[\s\S]*getDailyMissionWithCookie\(cleanCookie\)/, 'service must mark identity attempt before mission fetch to avoid repeated same-cookie failures')
assert.match(service, /cookie\.length[\s\S]*hash\.toString\(16\)/, 'cookie identity should be a length+hash fingerprint, not raw cookie storage')
assert.doesNotMatch(service, /saveLastAttemptDate\(context,\s*today,\s*cleanCookie\)/, 'service must not store the full cookie as the attempt identity')
assert.match(service, /if\s*\(!mission\.canRedeem\s*\|\|\s*!mission\.redeemPath\)\s*{[\s\S]*?'not-redeemable'/, 'service must not redeem when mission cannot redeem')
assert.match(service, /redeemDailyMissionWithCookie\([\s\S]*cleanCookie,[\s\S]*mission\.redeemPath[\s\S]*\)/, 'service must redeem when mission can redeem')
assert.doesNotMatch(service, /promptAction\.openToast|AlertDialog\.show/, 'auto service must stay quiet and not toast/dialog')

const startupOrder = [
  'restoreCookieJar(context)',
  'restoreAutoDailyCheckin(context, settingsStore)',
  'triggerStartupCheckin(context)',
].map((needle) => bootstrap.indexOf(needle))
assert.ok(startupOrder.every((idx) => idx >= 0), `startup trigger needles missing: ${startupOrder.join(', ')}`)
assert.ok(startupOrder[0] < startupOrder[1] && startupOrder[1] < startupOrder[2], 'startup trigger must run after cookie/settings load')
assert.match(entry, /SettingsBootstrap\.loadAll\(this\.context\)[\s\S]*this\.loadContent\(windowStage, win\)/, 'EntryAbility must load settings bootstrap before content')
assert.match(bootstrap, /CookieJarSettings\.getCurrentCookie\(\),\s*\n\s*'startup'/, 'startup trigger must use loaded current cookie')

for (const [name, source, tag] of [
  ['native login', nativeLogin, 'native-login'],
  ['web login', webLogin, 'web-login'],
  ['two-factor login', twoFactor, 'two-factor-login'],
]) {
  const authSave = source.indexOf('AuthSessionSettings.save')
  const trigger = source.indexOf(`AutoDailyCheckinService.tryCheckin`, authSave)
  assert.ok(authSave >= 0 && trigger > authSave, `${name} trigger must run after AuthSessionSettings.save`)
  assert.ok(source.includes(`'${tag}'`), `${name} trigger source tag must be present`)
}

assert.match(api, /async\s+getDailyMissionWithCookie\(cookie:\s*string\):\s*Promise<V2exDailyMission>[\s\S]*getCookieHtml\('\/mission\/daily',\s*cookie\)[\s\S]*V2exAccountParser\.extractDailyMission/, 'mission fetch API must still use /mission/daily parser path')
assert.match(api, /async\s+redeemDailyMissionWithCookie\([\s\S]*redeemPath:\s*string[\s\S]*getCookieHtml\(redeemPath,\s*cookie\)[\s\S]*return\s+this\.getDailyMissionWithCookie\(cookie\)/, 'mission redeem API must still redeem then refresh mission')
assert.ok(parser.includes('mission\\/daily\\/redeem\\?once=\\d+'), 'parser must still extract daily mission redeem once path')
assert.match(parser, /canRedeem:\s*true[\s\S]*redeemPath[\s\S]*message:\s*'今日可签到'/, 'parser must still mark redeemable mission')
assert.match(parser, /message:\s*done\s*\?\s*'今日已签到'\s*:\s*'暂不可签到'/, 'parser must still distinguish already-signed daily mission')

console.log('auto daily check-in static checks passed')
