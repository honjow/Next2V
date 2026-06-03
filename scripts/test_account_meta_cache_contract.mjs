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

const settingsPath = 'shared/src/main/ets/settings/AccountMetaSettings.ets'
assert(fs.existsSync(path.join(repo, settingsPath)), 'AccountMetaSettings.ets must exist')
const settings = read(settingsPath)
const stores = read('shared/src/main/ets/settings/SettingsStores.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const accountPage = read('entry/src/main/ets/pages/AccountPage.ets')
// Whitespace-flattened view so token checks survive the formatter wrapping call args across lines.
const accountPageFlat = accountPage.replace(/\s+/g, ' ')
const coordinator = read('entry/src/main/ets/model/AccountPageCoordinator.ets')

assert(stores.includes("STORE_NAME_ACCOUNT_META: string = 'next2v_account_meta'"), 'SettingsStores must declare a dedicated account meta store')
assert(settings.includes("import { STORE_NAME_ACCOUNT_META } from './SettingsStores'"), 'AccountMetaSettings must import its dedicated store')
assert(settings.includes('STORE_NAME: string = STORE_NAME_ACCOUNT_META'), 'AccountMetaSettings must bind STORE_NAME to STORE_NAME_ACCOUNT_META')
assert(sharedIndex.includes("export { AccountMetaSettings } from './settings/AccountMetaSettings'"), 'shared index must export AccountMetaSettings')
assert(sharedIndex.includes('AccountMetaSnapshot'), 'shared index must export AccountMetaSnapshot type')

for (const token of [
  'export interface AccountMetaSnapshot',
  'ownerKey: string',
  'source: string',
  'balance: V2exBalance | null',
  'dailyMission: V2exDailyMission | null',
  'updatedAt: number',
  'static ownerKey(username: string, source: string): string',
  "'member:' + cleanUsername + ':source:' + cleanSource",
  'static async loadCache',
  'static async saveCache',
  'static async clearCache',
  'store.putSync(KEY_ACCOUNT_META_CACHE, JSON.stringify(snapshot))',
  'store.deleteSync(KEY_ACCOUNT_META_CACHE)',
]) {
  assert(settings.includes(token), `AccountMetaSettings contract missing ${token}`)
}

for (const forbidden of [
  'cookie:',
  'token:',
  'once:',
  'rawHtml',
  'html:',
  'CookieJarSettings',
  'AuthSettings',
  'LOCAL_DATA_UPDATED_AT',
  'AppStorage.set',
  'AppStorage.setOrCreate',
]) {
  assert(!settings.includes(forbidden), `AccountMetaSettings must not store/publish secret or broad state field: ${forbidden}`)
}

const loadSessionStart = accountPage.indexOf('private loadSessionSnapshot(): void {')
const validateStart = accountPage.indexOf('private validateCookieSession', loadSessionStart)
assert(loadSessionStart >= 0 && validateStart > loadSessionStart, 'AccountPage loadSessionSnapshot boundaries missing')
const loadSessionBody = accountPage.slice(loadSessionStart, validateStart)
assert(
  loadSessionBody.indexOf('this.loadAccountMetaCache()') >= 0 &&
    loadSessionBody.indexOf('this.loadAccountMetaCache()') < loadSessionBody.indexOf('this.loadAccountMeta()'),
  'AccountPage must load matching cached account meta before network loadAccountMeta'
)

// Persistence + the live balance now flow through the shared AccountMetaState holder + the single-writer
// AccountMetaPublisher (which calls AccountMetaSettings.saveCache internally) instead of a per-page
// saveAccountMetaCache. The account-meta SOURCE is per-account (multi-account): 'cookie' or 'cookie:<id>'.
for (const token of [
  'AccountMetaSettings',
  'private accountMetaOwnerKey(): string',
  'AccountMetaSettings.ownerKey(this.currentUsername(), this.accountMetaSource())',
  'private accountMetaSource(): string',
  'private loadAccountMetaCache(): void',
  'AccountMetaSettings.loadCache(context, ownerKey)',
  'snapshot.ownerKey !== this.accountMetaOwnerKey()',
  'this.accountBalance = snapshot.balance',
  'this.dailyMission = snapshot.dailyMission',
  'private publishAccountMeta(cookie: string, ownerKey: string): void',
  'private clearAccountMetaCache(): void',
  'AccountMetaSettings.clearCache(context)',
]) {
  assert(accountPage.includes(token), `AccountPage account meta cache contract missing ${token}`)
}
// Calls the formatter may wrap across lines — match against the whitespace-flattened source.
for (const flatToken of [
  'AccountMetaPublisher.publishCached( snapshot.ownerKey, snapshot.balance, snapshot.dailyMission, )',
  'AccountMetaPublisher.publishFetched( context, ownerKey, this.accountBalance, this.dailyMission, this.accountMetaSource(), cookie, )',
]) {
  assert(accountPageFlat.includes(flatToken), `AccountPage account meta cache contract missing (flattened) ${flatToken}`)
}
// The per-page private cache writer is gone — persistence is the publisher's job (single writer).
assert(!accountPage.includes('private saveAccountMetaCache'), 'AccountPage must not keep a private cache writer; persistence belongs to AccountMetaPublisher')

const loadMetaStart = accountPage.indexOf('private loadAccountMeta(force: boolean = false): void {')
const redeemStart = accountPage.indexOf('private redeemDailyMission', loadMetaStart)
assert(loadMetaStart >= 0 && redeemStart > loadMetaStart, 'AccountPage loadAccountMeta boundaries missing')
const loadMetaBody = accountPage.slice(loadMetaStart, redeemStart)
assert(loadMetaBody.includes('this.publishAccountMeta(cookie, ownerKey)'), 'AccountPage must publish account meta (holder + cache) on successful network load')
assert(loadMetaBody.includes('if (!force && this.accountBalance && this.dailyMission)'), 'AccountPage should keep current/cached account meta and avoid unnecessary first load')
assert(accountPage.includes('this.loadAccountMeta(true)'), 'AccountPage daily mission/session success should still refresh account meta')
assert(accountPage.includes('this.clearAccountMetaCache()'), 'AccountPage must clear account meta cache on logout/session expiry or owner loss')
const publishMetaIndex = accountPage.indexOf('private publishAccountMeta(cookie: string, ownerKey: string): void')
const nextMethodAfterPublish = accountPage.indexOf('private clearAccountMetaCache', publishMetaIndex)
const publishMetaSection = accountPage.slice(publishMetaIndex, nextMethodAfterPublish)
assert(!publishMetaSection.includes('LOCAL_DATA_UPDATED_AT'), 'Account meta publish must not broadcast LOCAL_DATA_UPDATED_AT')

assert(
  coordinator.includes('if (accountBalance)') &&
    coordinator.indexOf('if (accountBalance)') < coordinator.indexOf('if (isAccountMetaLoading)'),
  'AccountPageCoordinator must keep cached/current balance text instead of 虚拟币同步中 while loading'
)

console.log('account meta cache contract ok')
