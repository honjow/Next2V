#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing meta cache contract in ${file}: ${needle}`)
  }
}

function assertNotIncludes(file, text, needle) {
  if (text.includes(needle)) {
    fail(`forbidden meta cache contract in ${file}: ${needle}`)
  }
}

function methodBody(text, methodName) {
  const marker = methodName.includes('(') ? methodName : `${methodName}(`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
  }
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') depth += 1
    if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  fail(`unterminated method body for: ${marker}`)
}

const settingsPath = 'shared/src/main/ets/settings/BlockedListSettings.ets'
const storageKeysPath = 'shared/src/main/ets/constants/StorageKeys.ets'
const pagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'

const settings = source(settingsPath)
const storageKeys = source(storageKeysPath)
const page = source(pagePath)

assertIncludes(storageKeysPath, storageKeys, 'BLOCKED_LIST_BLOCKED_MEMBER_METAS')

assertIncludes(settingsPath, settings, 'export interface BlockedMemberMeta')
assertIncludes(settingsPath, settings, 'blockedMemberMetas: BlockedMemberMeta[]')
assertIncludes(settingsPath, settings, 'blockedMemberMetas: []')
assertIncludes(settingsPath, settings, 'StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS')
assertIncludes(settingsPath, settings, 'parseRuntimeMemberMetas()')
assertIncludes(settingsPath, settings, 'normalizeMemberMetas')
assertIncludes(settingsPath, settings, 'private static snapshotWriteQueue: Promise<void> = Promise.resolve()')
assertIncludes(settingsPath, settings, 'private static enqueueSnapshotWrite(action: () => Promise<void>): Promise<void>')
assertIncludes(settingsPath, settings, 'BlockedListSettings.snapshotWriteQueue = task.catch((_error: Error) => {})')
assertIncludes(settingsPath, settings, 'private static async upsertBlockedMemberMetaLocked(')
assertIncludes(settingsPath, settings, 'return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.upsertBlockedMemberMetaLocked(ownerKey, normalizedMeta, context, source))')
assertIncludes(settingsPath, settings, 'static async upsertBlockedMemberMeta(')
assertIncludes(settingsPath, settings, 'blocked_member_meta_upsert_success')
assertIncludes(settingsPath, settings, 'blocked_member_meta_skip_not_blocked')
assertIncludes(settingsPath, settings, 'blocked_member_meta_count')

function sectionBefore(text, startNeedle, endNeedle) {
  const start = text.indexOf(startNeedle)
  if (start < 0) {
    fail(`missing section start: ${startNeedle}`)
  }
  const end = text.indexOf(endNeedle, start + startNeedle.length)
  if (end < 0) {
    fail(`missing section end after ${startNeedle}: ${endNeedle}`)
  }
  return text.slice(start, end)
}

const saveActiveBody = sectionBefore(settings, 'static async saveActive', '\n  static updateFromTopicListHtml')
assertIncludes(settingsPath, saveActiveBody, 'const immediate = BlockedListSettings.normalize')
assertIncludes(settingsPath, saveActiveBody, 'BlockedListSettings.apply(immediate)')
assertIncludes(settingsPath, saveActiveBody, 'return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.persistSavedSnapshot(immediate, ctx, source))')
assertNotIncludes(settingsPath, saveActiveBody, 'await BlockedListSettings.snapshotForDelta')

const deltaBody = methodBody(settings, 'private static nextDeltaSnapshot')
assertIncludes(settingsPath, deltaBody, 'blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(base.blockedMemberMetas, blockedMemberIds)')
assertIncludes(settingsPath, deltaBody, 'blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(base.blockedMemberMetas, BlockedListSettings.nextIds(blockedMemberIds, targetId, deltaValue))')

const upsertPublicBody = sectionBefore(settings, 'static async upsertBlockedMemberMeta', '\n  private static async upsertBlockedMemberMetaLocked')
assertIncludes(settingsPath, upsertPublicBody, 'const ownerKey = BlockedListSettings.activeOwnerKey()')
assertIncludes(settingsPath, upsertPublicBody, 'const normalizedMeta = BlockedListSettings.normalizeMemberMeta(meta)')
assertIncludes(settingsPath, upsertPublicBody, 'return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.upsertBlockedMemberMetaLocked(ownerKey, normalizedMeta, context, source))')

const upsertBody = sectionBefore(settings, 'private static async upsertBlockedMemberMetaLocked', '\n  static apply')
assertIncludes(settingsPath, upsertBody, 'const base = await BlockedListSettings.snapshotForOwnerWrite(ctx, ownerKey)')
assertIncludes(settingsPath, upsertBody, 'base.blockedMemberIds.indexOf(normalizedMeta.id) < 0')
assertIncludes(settingsPath, upsertBody, 'if (BlockedListSettings.activeOwnerKey() === ownerKey)')
assertIncludes(settingsPath, upsertBody, 'setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS')
assertIncludes(settingsPath, upsertBody, 'store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))')
assertNotIncludes(settingsPath, upsertBody, 'const ownerKey = BlockedListSettings.activeOwnerKey()')
assertNotIncludes(settingsPath, upsertBody, 'BlockedListSettings.apply(normalized)')

const applyIdDeltaBody = sectionBefore(settings, 'private static async applyIdDelta', '\n  private static async applyIdDeltaLocked')
assertIncludes(settingsPath, applyIdDeltaBody, 'const immediate = BlockedListSettings.normalize')
assertIncludes(settingsPath, applyIdDeltaBody, 'BlockedListSettings.apply(immediate)')
assertIncludes(settingsPath, applyIdDeltaBody, 'return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.applyIdDeltaLocked(immediate, ctx, source, deltaType, normalizedId, deltaValue))')

assertNotIncludes(settingsPath, settings, 'snapshotForDelta(ctx, ownerKey)')

assertIncludes(pagePath, page, 'type BlockedMemberMeta')
assertIncludes(pagePath, page, 'applyMeta(meta: BlockedMemberMeta)')
assertIncludes(pagePath, page, 'toMeta(): BlockedMemberMeta')
assertIncludes(pagePath, page, 'private applyMemberMetaCache')
assertIncludes(pagePath, page, 'this.applyMemberMetaCache(snapshot.blockedMemberMetas)')
assertIncludes(pagePath, page, 'BlockedListSettings.upsertBlockedMemberMeta(row.toMeta()')
assertIncludes(pagePath, page, 'blocked_member_meta_cache_hydrated')

const applySnapshotBody = methodBody(page, 'private applySnapshot')
const ensureIndex = applySnapshotBody.indexOf('this.members = this.ensureMemberRowsForIds')
const hydrateIndex = applySnapshotBody.indexOf('this.applyMemberMetaCache(snapshot.blockedMemberMetas)')
const resolveIndex = applySnapshotBody.indexOf('this.resolveMembers(snapshot.blockedMemberIds)')
if (ensureIndex < 0 || hydrateIndex < 0 || resolveIndex < 0 || !(ensureIndex < hydrateIndex && hydrateIndex < resolveIndex)) {
  fail('BlockedListsPage must hydrate cached member meta after row creation and before async resolveMembers')
}

console.log('PASS: blocked member meta cache contract')
