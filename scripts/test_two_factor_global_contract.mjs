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

const service = read('shared/src/main/ets/services/TwoFactorChallengeService.ets')
for (const token of [
  'export class TwoFactorChallengeService',
  'static request(cookie: string',
  'StorageKeys.TWO_FACTOR_COOKIE',
  'StorageKeys.TWO_FACTOR_SOURCE',
  'StorageKeys.TWO_FACTOR_VISIBLE',
  'static complete()',
  'StorageKeys.TWO_FACTOR_COMPLETED_AT',
]) {
  assert(service.includes(token), `TwoFactorChallengeService contract missing ${token}`)
}

const index = read('entry/src/main/ets/pages/Index.ets')
for (const token of [
  'GlobalTwoFactorSheet',
  'V2exTwoFactorPrompt({',
  'StorageKeys.TWO_FACTOR_VISIBLE',
  'StorageKeys.TWO_FACTOR_COOKIE',
  'StorageKeys.TWO_FACTOR_SOURCE',
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
