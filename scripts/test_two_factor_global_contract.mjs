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
// publish* helpers, which write the V2 mirror Index reads/@Monitors. The two request/complete timestamp
// breadcrumbs remain plain AppStorage writes (write-only; no mirror, no reader to migrate).
const service = read('shared/src/main/ets/services/TwoFactorChallengeService.ets')
for (const token of [
  'export class TwoFactorChallengeService',
  'static request(cookie: string',
  'publishTwoFactorCookie',
  'publishTwoFactorSource',
  'publishTwoFactorVisible',
  'static complete()',
  'StorageKeys.TWO_FACTOR_COMPLETED_AT',
]) {
  assert(service.includes(token), `TwoFactorChallengeService contract missing ${token}`)
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

for (const rel of [
  'entry/src/main/ets/pages/AccountPage.ets',
  'entry/src/main/ets/pages/MyTopicsPage.ets',
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
]) {
  const text = read(rel)
  assert(!text.includes('V2exTwoFactorPrompt'), `${rel} must not own a local 2FA sheet`)
  assert(!text.includes('twoFactorVisible'), `${rel} must not own local twoFactorVisible state`)
  assert(!text.includes('twoFactorCookie'), `${rel} must not own local twoFactorCookie state`)
  assert(text.includes('TwoFactorChallengeService.request'), `${rel} must publish global 2FA challenge`)
}

const notificationPage = read('entry/src/main/ets/pages/NotificationPage.ets')
assert(notificationPage.includes('TwoFactorChallengeService.request'), 'NotificationPage must publish global 2FA challenge')
assert(notificationPage.includes('V2exCookieTwoFactorRequiredError'), 'NotificationPage must detect cookie 2FA errors')

console.log('global 2fa contract ok')
