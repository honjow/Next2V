#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

// State Management V2 migration: the service routes the 2FA sheet state through the TwoFactorState
// publish* helpers, which write the V2 mirror Index reads/@Monitors. V2-only — the service makes NO direct
// AppStorage writes: the former write-only TWO_FACTOR_REQUESTED_AT/COMPLETED_AT timestamp breadcrumbs were
// retired (zero runtime readers), so request()/complete()/cancel() drive the V2 mirror exclusively.
const service = read('shared/src/main/ets/services/TwoFactorChallengeService.ets')
for (const token of [
  'export class TwoFactorChallengeService',
  'static request(cookie: string',
  'publishTwoFactorCookie',
  'publishTwoFactorSource',
  'publishTwoFactorVisible',
  'static complete()',
  'static cancel()',
  'static clear()',
]) {
  assert(service.includes(token), `TwoFactorChallengeService contract missing ${token}`)
}
// V2-only: the service must make NO direct AppStorage writes and must not reference any legacy TwoFactor
// AppStorage key. Strip comments first so a documentary NOTE can't satisfy the guard.
const serviceCode = service.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')
assert(!/\bAppStorage\s*\./.test(serviceCode), 'TwoFactorChallengeService must make no direct AppStorage writes (V2-only)')
for (const key of ['TWO_FACTOR_REQUESTED_AT', 'TWO_FACTOR_COMPLETED_AT', 'TWO_FACTOR_VISIBLE', 'TWO_FACTOR_COOKIE', 'TWO_FACTOR_SOURCE']) {
  assert(!serviceCode.includes(key), `TwoFactorChallengeService must not reference the retired StorageKeys.${key}`)
}
// complete()/cancel() both clear the V2 mirror through clear(), which routes through the publish* helpers.
for (const token of ['publishTwoFactorVisible(false)', "publishTwoFactorCookie('')", "publishTwoFactorSource('')"]) {
  assert(service.includes(token), `TwoFactorChallengeService.clear must reset the V2 mirror via ${token}`)
}
// V2-only: the publish* helpers write the @Trace mirror only. The legacy TWO_FACTOR_VISIBLE/COOKIE/SOURCE
// AppStorage halves were retired once Index (the sole reader) read the mirror instead; guard against
// reintroduction and require each publish* helper to still drive its mirror field.
const twoFactorState = read('shared/src/main/ets/state/TwoFactorState.ets')
for (const key of ['TWO_FACTOR_COOKIE', 'TWO_FACTOR_SOURCE', 'TWO_FACTOR_VISIBLE']) {
  assert(
    !new RegExp(`AppStorage\\.(set|setOrCreate)<[^>]*>\\(\\s*StorageKeys\\.${key}`).test(twoFactorState),
    `TwoFactorState must not reintroduce the legacy StorageKeys.${key} dual-write (V2-only)`,
  )
}
for (const field of ['connectTwoFactor().visible', 'connectTwoFactor().cookie', 'connectTwoFactor().source']) {
  assert(twoFactorState.includes(field), `TwoFactorState publish* must drive the V2 mirror field ${field}`)
}

// Index reads the global 2FA state from the V2 TwoFactorState mirror (was StorageKeys.TWO_FACTOR_*):
//   StorageKeys.TWO_FACTOR_VISIBLE -> @Local twoFactorVisible synced via @Monitor('twoFactor.visible')
//   StorageKeys.TWO_FACTOR_COOKIE  -> this.twoFactor.cookie
//   StorageKeys.TWO_FACTOR_SOURCE  -> this.twoFactor.source
const index = read('entry/src/main/ets/pages/Index.ets')
for (const token of [
  'GlobalTwoFactorSheet',
  'V2exTwoFactorPrompt({',
  'connectTwoFactor()',
  'this.twoFactor.cookie',
  'this.twoFactor.source',
  'TwoFactorChallengeService.complete()',
  "source === 'nativeLogin'",
]) {
  assert(index.includes(token), `Index global 2FA contract missing ${token}`)
}

const apiService = read('shared/src/main/ets/network/ApiService.ets')
for (const token of [
  'assertNoTwoFactorChallenge',
  'requestTwoFactorChallenge',
  'TwoFactorChallengeService.request(cleanCookie, path)',
  "ApiService.isLocationPath(location, '/2fa')",
  'V2exSigninParser.extractTwoFactorForm(text)',
  'validateSessionWithCookie',
]) {
  assert(apiService.includes(token), `ApiService global 2FA trigger contract missing ${token}`)
}

const nativeAuthService = read('shared/src/main/ets/network/V2exNativeAuthService.ets')
for (const token of [
  'normalizeTwoFactorCode',
  'String.fromCharCode(codeUnit - 65248)',
  'cleanCode.length !== 6',
  "private static readonly TWO_FACTOR_VERIFY_PATH: string = '/balance'",
  'authBaseUrlFor',
  'authActionUrl',
  "return [{ key: challenge.codeField || 'code', value: cleanCode }]",
]) {
  assert(nativeAuthService.includes(token), `Native auth 2FA safety contract missing ${token}`)
}
assert(!nativeAuthService.includes('const cleanCode = code.trim()'), 'Native 2FA completion must normalize copied codes, not only trim them')
assert(!nativeAuthService.includes('pairs.push({ key, value: hiddenFields[key] })'), 'Native 2FA POST must not replay hidden/button fields')
assert(!nativeAuthService.includes("DiagnosticLogger.info('two_factor'"), 'Native 2FA path must not keep temporary diagnostic info logs')
assert(!nativeAuthService.includes("DiagnosticLogger.warn('two_factor'"), 'Native 2FA path must not keep temporary diagnostic warning logs')
assert(
  nativeAuthService.indexOf('TWO_FACTOR_VERIFY_PATH') < nativeAuthService.indexOf('SETTINGS_PATH}`, http.RequestMethod.GET, cookieAfterVerify'),
  'Native 2FA completion must verify a gated endpoint before using /settings for username extraction',
)

const twoFactorPrompt = read('entry/src/main/ets/components/V2exTwoFactorPrompt.ets')
for (const token of [
  'const cleanCode = this.normalizeTwoFactorCode(this.code)',
  'this.code = cleanCode',
  'cleanCode.length !== 6',
  'String.fromCharCode(codeUnit - 65248)',
]) {
  assert(twoFactorPrompt.includes(token), `V2exTwoFactorPrompt copied-code normalization missing ${token}`)
}
assert(!twoFactorPrompt.includes('const cleanCode = this.code.trim()'), 'V2exTwoFactorPrompt must normalize copied codes, not only trim them')

for (const rel of [
  'entry/src/main/ets/pages/AccountPage.ets',
  'entry/src/main/ets/pages/MyTopicsPage.ets',
  'entry/src/main/ets/pages/NotificationPage.ets',
]) {
  const text = read(rel)
  assert(!text.includes('V2exTwoFactorPrompt'), `${rel} must not own a local 2FA sheet`)
  assert(!text.includes('twoFactorVisible'), `${rel} must not own local twoFactorVisible state`)
  assert(!text.includes('twoFactorCookie'), `${rel} must not own local twoFactorCookie state`)
  assert(!text.includes('TwoFactorChallengeService.request'), `${rel} must not publish 2FA directly; cookie HTML requests trigger globally in ApiService`)
  assert(text.includes('V2exCookieTwoFactorRequiredError'), `${rel} must still identify cookie 2FA errors for local loading/error state`)
}

const nativeLoginPage = read('entry/src/main/ets/pages/V2exNativeLoginPage.ets')
assert(!nativeLoginPage.includes('V2exTwoFactorPrompt'), 'native login must not own a local 2FA sheet')
assert(nativeLoginPage.includes('TwoFactorChallengeService.request'), 'native login may publish the non-cookie-login 2FA challenge')

console.log('global 2fa contract ok')
