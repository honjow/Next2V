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

// State Management V2 migration: the service routes the TWO_FACTOR_* AppStorage writes through the
// TwoFactorState write-through helpers (publish*), which keep the V1 keys AND the V2 mirror in lockstep.
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
// The write-through helpers must still write the V1 AppStorage keys so any V1 reader stays in sync.
const twoFactorState = read('shared/src/main/ets/state/TwoFactorState.ets')
for (const key of ['TWO_FACTOR_COOKIE', 'TWO_FACTOR_SOURCE', 'TWO_FACTOR_VISIBLE']) {
  assert(twoFactorState.includes(`StorageKeys.${key}`), `TwoFactorState write-through must still write StorageKeys.${key}`)
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
