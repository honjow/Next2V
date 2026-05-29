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
    fail(`missing ignored-topic meta cache contract in ${file}: ${needle}`)
  }
}

function assertNotIncludes(file, text, needle) {
  if (text.includes(needle)) {
    fail(`forbidden ignored-topic meta cache contract in ${file}: ${needle}`)
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

const settingsPath = 'shared/src/main/ets/settings/BlockedListSettings.ets'
const storageKeysPath = 'shared/src/main/ets/constants/StorageKeys.ets'
const indexPath = 'shared/src/main/ets/Index.ets'
const pagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'

const settings = source(settingsPath)
const storageKeys = source(storageKeysPath)
const index = source(indexPath)
const page = source(pagePath)

assertIncludes(storageKeysPath, storageKeys, 'BLOCKED_LIST_IGNORED_TOPIC_METAS')
assertIncludes(indexPath, index, 'IgnoredTopicMeta')

assertIncludes(settingsPath, settings, 'export interface IgnoredTopicMeta')
for (const field of ['id: number', 'title: string', 'nodeName: string', 'nodeTitle: string', 'username: string', 'avatar: string', 'memberPro: number', 'created: number', 'replies: number', 'updatedAt: number']) {
  assertIncludes(settingsPath, settings, field)
}
assertIncludes(settingsPath, settings, 'ignoredTopicMetas: IgnoredTopicMeta[]')
assertIncludes(settingsPath, settings, 'ignoredTopicMetas: []')
assertIncludes(settingsPath, settings, 'parseRuntimeIgnoredTopicMetas()')
assertIncludes(settingsPath, settings, 'normalizeIgnoredTopicMetas')
assertIncludes(settingsPath, settings, 'static async upsertIgnoredTopicMetas(')
assertIncludes(settingsPath, settings, 'private static async upsertIgnoredTopicMetasLocked(')
assertIncludes(settingsPath, settings, 'ignored_topic_meta_upsert_success')
assertIncludes(settingsPath, settings, 'ignored_topic_meta_count')

const saveActiveBody = sectionBefore(settings, 'static async saveActive', '\n  static updateFromTopicListHtml')
assertIncludes(settingsPath, saveActiveBody, 'const runtimeTopicMetas = runtime.ownerKey === ownerKey ? runtime.ignoredTopicMetas : []')
assertIncludes(settingsPath, saveActiveBody, 'ignoredTopicMetas: runtimeTopicMetas')

const upsertPublicBody = sectionBefore(settings, 'static async upsertIgnoredTopicMetas', '\n  private static async upsertIgnoredTopicMetasLocked')
assertIncludes(settingsPath, upsertPublicBody, 'const ownerKey = BlockedListSettings.activeOwnerKey()')
assertIncludes(settingsPath, upsertPublicBody, 'const normalizedMetas =')
assertIncludes(settingsPath, upsertPublicBody, 'return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.upsertIgnoredTopicMetasLocked(ownerKey, normalizedMetas, context, source))')

const upsertLockedBody = sectionBefore(settings, 'private static async upsertIgnoredTopicMetasLocked', '\n  private static async applyIdDelta')
assertIncludes(settingsPath, upsertLockedBody, 'const base = await BlockedListSettings.snapshotForOwnerWrite(ctx, ownerKey)')
assertIncludes(settingsPath, upsertLockedBody, 'allowedIds.has(meta.id)')
assertIncludes(settingsPath, upsertLockedBody, 'if (BlockedListSettings.activeOwnerKey() === ownerKey)')
assertIncludes(settingsPath, upsertLockedBody, 'setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_METAS')
assertIncludes(settingsPath, upsertLockedBody, 'store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))')
assertNotIncludes(settingsPath, upsertLockedBody, 'const ownerKey = BlockedListSettings.activeOwnerKey()')

const deltaBody = methodBody(settings, 'private static nextDeltaSnapshot')
assertIncludes(settingsPath, deltaBody, 'ignoredTopicMetas: BlockedListSettings.normalizeIgnoredTopicMetas(base.ignoredTopicMetas, BlockedListSettings.nextIds(ignoredTopicIds, targetId, deltaValue))')
assertIncludes(settingsPath, deltaBody, 'ignoredTopicMetas: BlockedListSettings.normalizeIgnoredTopicMetas(base.ignoredTopicMetas, ignoredTopicIds)')

assertIncludes(pagePath, page, 'type IgnoredTopicMeta')
assertIncludes(pagePath, page, 'private applyIgnoredTopicMetaCache')
assertIncludes(pagePath, page, 'this.applyIgnoredTopicMetaCache(snapshot.ignoredTopicIds, snapshot.ignoredTopicMetas)')
assertIncludes(pagePath, page, 'private topicFromMeta(meta: IgnoredTopicMeta): V2exTopic')
assertIncludes(pagePath, page, 'private toIgnoredTopicMeta(topic: V2exTopic): IgnoredTopicMeta')
assertIncludes(pagePath, page, 'private persistIgnoredTopicMetas')
assertIncludes(pagePath, page, 'BlockedListSettings.upsertIgnoredTopicMetas(metas')
assertIncludes(pagePath, page, 'ignored_topic_meta_cache_hydrated')
assertIncludes(pagePath, page, 'ignored_topic_meta_count: snapshot.ignoredTopicMetas.length')

const applySnapshotBody = methodBody(page, 'private applySnapshot')
const hydrateIndex = applySnapshotBody.indexOf('this.applyIgnoredTopicMetaCache(snapshot.ignoredTopicIds, snapshot.ignoredTopicMetas)')
const resolveIndex = applySnapshotBody.indexOf('this.resolveTopics(snapshot.ignoredTopicIds)')
if (hydrateIndex < 0 || resolveIndex < 0 || !(hydrateIndex < resolveIndex)) {
  fail('BlockedListsPage must hydrate cached ignored-topic metas before async resolveTopics')
}

const loadingBody = methodBody(page, 'private shouldShowPageLoading')
assertNotIncludes(pagePath, loadingBody, 'hasIdsForCurrentTab()')
assertIncludes(pagePath, loadingBody, 'hasAnyRenderableForCurrentTab()')
assertIncludes(pagePath, loadingBody, 'isRefreshPendingForCurrentTab()')

console.log('PASS: ignored topic meta cache contract')
