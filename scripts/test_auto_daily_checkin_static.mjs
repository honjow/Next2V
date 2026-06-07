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
// State Management V2: the switch state is a @Local synced from the AutoDailyCheckin V2 holder (the V1
// @StorageLink decorator is retired). See connectAutoDailyCheckin() / AutoDailyCheckinState.
assert.match(settingsPage, /@Local\s+private\s+autoDailyCheckinEnabled:\s*boolean\s*=\s*true/, 'SettingsPage must hold the auto check-in switch state in a @Local (V2)')
assert.match(settingsPage, /this\.autoDailyCheckinEnabled\s*=\s*connectAutoDailyCheckin\(\)\.enabled/, 'SettingsPage must sync the switch from the AutoDailyCheckin V2 holder')
assert.match(accountSection, /TogglePreferenceRow\(\s*AppStrings\.R_AUTO_CHECKIN,\s*this\.autoDailyCheckinEnabled/, 'account section must show the auto check-in (R_AUTO_CHECKIN) switch row')
assert.doesNotMatch(accountSection, /Button\('自动签到'|FilterChip\(|Chip\(/, 'auto daily check-in must not be implemented as button/chip')
assert.match(settingsPage, /SettingsSaveCoordinator\.saveAutoDailyCheckin\(context,\s*enabled\)/, 'switch updates must persist via helper')

assert.match(service, /if\s*\(!AutoDailyCheckinSettings\.isEnabled\(\)\)\s*{[\s\S]*?'disabled'/, 'service must skip when disabled')
assert.match(service, /if\s*\(!cleanCookie\)\s*{[\s\S]*?'no-cookie'/, 'service must skip without cookie')
assert.match(service, /if\s*\(AutoDailyCheckinService\.inFlight\)\s*{[\s\S]*?'in-flight'/, 'service must guard concurrent runs')
assert.match(service, /const\s+attemptIdentity\s*=\s*AutoDailyCheckinService\.cookieAttemptIdentity\(cleanCookie\)/, 'service must derive a non-cookie identity for the current cookie')
assert.match(service, /getLastAttemptDate\(\)\s*===\s*today\s*&&\s*\n\s*AutoDailyCheckinSettings\.getLastAttemptIdentity\(\)\s*===\s*attemptIdentity[\s\S]*?'already-attempted'/, 'service must skip same local day only for the same cookie identity')
// The redeem can't go over HTTP (V2EX's anti-bot blocks a headless request; a real ArkWeb engine passes —
// verified on-device and by the user). So when the mission is redeemable, tryCheckin marks the day attempted
// then hands off to the hidden runner via requestWebRedeem(); the runner reports back through handleWebResult,
// which persists the success breadcrumb + reward toast only on a confirmed claim ('success' / 'already').
assert.match(service, /saveLastAttemptDate\(context,\s*today,\s*attemptIdentity\)[\s\S]*?requestWebRedeem\(\)/, 'service marks the day attempted, then hands the redeem off to the web runner')
assert.match(service, /requestWebRedeem\(\)[\s\S]*?connectWebCheckinRunner\(\)[\s\S]*?requestId\s*=\s*runner\.requestId\s*\+\s*1/, 'requestWebRedeem bumps the runner command bus (requestId)')
assert.match(service, /static async handleWebResult\([\s\S]*?status\s*!==\s*'success'\s*&&\s*status\s*!==\s*'already'[\s\S]*?saveLastSuccessDate/, 'handleWebResult persists success only on a confirmed claim (success/already)')
assert.doesNotMatch(service, /redeemDailyMissionWithCookie/, 'auto service must NOT redeem over HTTP (the anti-bot blocks a headless redeem)')
assert.match(service, /cookie\.length[\s\S]*hash\.toString\(16\)/, 'cookie identity should be a length+hash fingerprint, not raw cookie storage')
assert.doesNotMatch(service, /saveLastAttemptDate\(context,\s*today,\s*cleanCookie\)/, 'service must not store the full cookie as the attempt identity')
assert.match(service, /if\s*\(!mission\.canRedeem\s*\|\|\s*!mission\.redeemPath\)\s*{[\s\S]*?'not-redeemable'/, 'service must not redeem when mission cannot redeem')
assert.match(service, /promptAction\.openToast/, 'auto service surfaces a non-blocking reward toast on a successful auto check-in')
assert.doesNotMatch(service, /AlertDialog\.show/, 'auto service must not block with a dialog')

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
// Redeem must issue the redeem request then CONFIRM via a fresh /mission/daily fetch requiring a
// definitive already-done state — the 302 body is not trusted (that false-success was the day-burning bug).
assert.match(api, /async\s+redeemDailyMissionWithCookie\([\s\S]*?getCookieHtml\(fresh\.redeemPath,\s*cookie[\s\S]*?getCookieHtml\(\s*'\/mission\/daily',[\s\S]*?extractDailyMission\(verifyHtml\)[\s\S]*?after\.message\s*!==\s*'already_checked_in_today'/, 'redeem must confirm the claim via a fresh mission fetch (no false success on the 302)')
assert.ok(parser.includes('mission\\/daily\\/redeem\\?once=\\d+'), 'parser must still extract daily mission redeem once path')
assert.match(parser, /canRedeem:\s*true,\s*redeemPath,\s*message:\s*'daily_checkin_available'/, 'parser must still mark redeemable mission')
assert.match(parser, /message:\s*done\s*\?\s*'already_checked_in_today'\s*:\s*'daily_checkin_unavailable'/, 'parser must still distinguish already-signed daily mission')

console.log('auto daily check-in static checks passed')
