import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { V2exReply, V2exTopic } from '../network/NetworkTypes'
import { LocalDataStore } from '../storage/LocalDataStore'
import {
  cleanupPreparedPayloadFile,
  commitStagedPayloadFile,
  deleteOrphanPayloadFiles,
  payloadHash,
  preparePayloadStorage,
  resolvePayloadText,
  topicDetailPayloadFileName,
  topicListPayloadFileName,
  unlinkPayloadFileBestEffort,
} from './CachePayloadFiles'
import {
  CACHE_KIND_TOPIC_DETAIL,
  CACHE_KIND_TOPIC_LIST,
  CACHE_KINDS_SQL,
  KEY_CACHE_INDEX,
  KEY_PREFIX_TOPIC_DETAIL,
  KEY_PREFIX_TOPIC_LIST,
  MAX_CACHE_PAYLOAD_SIZE,
  MAX_TOPIC_LIST_ITEMS,
  TOPIC_DETAIL_TTL_SECONDS,
  TOPIC_LIST_TTL_SECONDS,
} from './CachePolicy'
import { deleteKeysAndFlush, SettingsPreferencesStore, withPreferencesStore } from './SettingsStorage'
import { STORE_NAME_CACHE } from './SettingsStores'
import { AppStrings } from '../i18n/AppStrings'

const STORE_NAME: string = STORE_NAME_CACHE

const SQL_SELECT_CACHE_ENTRY: string = 'SELECT payload_text, payload_path, payload_hash, expires_at FROM cache_entries WHERE cache_key = ? AND kind = ? LIMIT 1'
const SQL_SELECT_CACHE_INDEX: string = `SELECT cache_key, kind, cached_at, accessed_at FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) ORDER BY cached_at DESC`
const SQL_SELECT_CACHE_STATS: string = `SELECT kind, COUNT(*) AS count_value, MAX(cached_at) AS updated_at FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) GROUP BY kind`
const SQL_UPSERT_CACHE_ENTRY: string = 'INSERT OR REPLACE INTO cache_entries (cache_key, kind, payload_text, payload_path, payload_hash, cached_at, accessed_at, expires_at, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
const SQL_TOUCH_CACHE_ENTRY: string = 'UPDATE cache_entries SET accessed_at = ? WHERE cache_key = ? AND kind = ?'
const SQL_SELECT_CACHE_ENTRY_PAYLOAD_PATH: string = 'SELECT payload_path FROM cache_entries WHERE cache_key = ? AND kind = ? LIMIT 1'
const SQL_DELETE_CACHE_ENTRY: string = 'DELETE FROM cache_entries WHERE cache_key = ? AND kind = ?'
const SQL_SELECT_EXPIRED_CACHE_PAYLOAD_PATHS: string = `SELECT payload_path FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) AND expires_at <= ?`
const SQL_DELETE_EXPIRED_CACHE_ENTRIES: string = `DELETE FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) AND expires_at <= ?`
const SQL_SELECT_CLEAR_CACHE_PAYLOAD_PATHS: string = `SELECT payload_path FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL})`
const SQL_CLEAR_CACHE_ENTRIES: string = `DELETE FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL})`
const SQL_SELECT_PRUNE_TOPIC_LIST_PAYLOAD_PATHS: string = 'SELECT payload_path FROM cache_entries WHERE kind = \'topic_list\' AND cache_key NOT IN (SELECT cache_key FROM cache_entries WHERE kind = \'topic_list\' ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 32)'
const SQL_PRUNE_TOPIC_LIST_ROWS: string = 'DELETE FROM cache_entries WHERE kind = \'topic_list\' AND cache_key NOT IN (SELECT cache_key FROM cache_entries WHERE kind = \'topic_list\' ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 32)'
const SQL_SELECT_PRUNE_TOPIC_DETAIL_PAYLOAD_PATHS: string = 'SELECT payload_path FROM cache_entries WHERE kind = \'topic_detail\' AND cache_key NOT IN (SELECT cache_key FROM cache_entries WHERE kind = \'topic_detail\' ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 200)'
const SQL_PRUNE_TOPIC_DETAIL_ROWS: string = 'DELETE FROM cache_entries WHERE kind = \'topic_detail\' AND cache_key NOT IN (SELECT cache_key FROM cache_entries WHERE kind = \'topic_detail\' ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 200)'
const SQL_SELECT_CACHE_PAYLOAD_SIZE: string = `SELECT COALESCE(SUM(size), 0) AS total_size FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL})`
const SQL_SELECT_PRUNE_CACHE_PAYLOAD_PATHS: string = `SELECT payload_path FROM cache_entries WHERE cache_key IN (SELECT cache_key FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) ORDER BY accessed_at ASC, cached_at ASC, cache_key ASC LIMIT ?)`
const SQL_PRUNE_CACHE_PAYLOAD_SIZE: string = `DELETE FROM cache_entries WHERE cache_key IN (SELECT cache_key FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) ORDER BY accessed_at ASC, cached_at ASC, cache_key ASC LIMIT ?)`
const SQL_SELECT_ACTIVE_CACHE_PAYLOAD_PATHS: string = `SELECT payload_path FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) AND payload_path IS NOT NULL`

export interface TopicDetailCache {
  topic: V2exTopic | null
  replies: V2exReply[]
  cachedAt: number
}

export interface CacheStats {
  topicListCount: number
  topicDetailCount: number
  updatedAt: number
}

export interface CacheKeyIndex {
  topicLists: string[]
  topicDetails: number[]
  updatedAt: number
}

interface LegacyCacheIndex {
  topicLists: string[]
  topicDetails: string[]
  updatedAt: number
}

interface CacheEntry {
  payloadText: string
  payloadPath: string
  expiresAt: number
}

export class CacheSettings {
  static async loadKeyIndex(context: common.UIAbilityContext): Promise<CacheKeyIndex> {
    try {
      const now = CacheSettings.nowSeconds()
      const store = await LocalDataStore.open(context)
      await CacheSettings.deleteExpiredRows(context, store, now)
      const resultSet = await store.querySql(SQL_SELECT_CACHE_INDEX)
      return CacheSettings.readKeyIndexResult(resultSet)
    } catch (error) {
      return { topicLists: [], topicDetails: [], updatedAt: 0 }
    }
  }

  static async loadTopicList(context: common.UIAbilityContext, cacheKey: string): Promise<V2exTopic[]> {
    try {
      const rowKey = CacheSettings.topicListRowKey(cacheKey)
      const store = await LocalDataStore.open(context)
      const row = await CacheSettings.loadCacheEntry(context, store, rowKey, CACHE_KIND_TOPIC_LIST)
      if (!row) {
        return []
      }
      const parsed = CacheSettings.parseTopicList(row.payloadText)
      if (parsed.length <= 0) {
        await CacheSettings.deleteCacheEntry(context, store, rowKey, CACHE_KIND_TOPIC_LIST)
        return []
      }
      await CacheSettings.touchCacheEntry(store, rowKey, CACHE_KIND_TOPIC_LIST)
      return parsed
    } catch (error) {
      return []
    }
  }

  static async saveTopicList(context: common.UIAbilityContext, cacheKey: string, topics: V2exTopic[]): Promise<void> {
    try {
      const now = CacheSettings.nowSeconds()
      const next = topics.slice(0, MAX_TOPIC_LIST_ITEMS)
      const payload = JSON.stringify(next)
      const store = await LocalDataStore.open(context)
      await CacheSettings.saveCacheEntry(
        context,
        store,
        CacheSettings.topicListRowKey(cacheKey),
        CACHE_KIND_TOPIC_LIST,
        topicListPayloadFileName(CacheSettings.topicListRowKey(cacheKey)),
        payload,
        now,
        now + TOPIC_LIST_TTL_SECONDS
      )
      await CacheSettings.pruneCache(context, store, now)
      CacheSettings.deleteLegacyCacheBestEffort(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save list cache')
    }
  }

  static async loadTopicDetail(context: common.UIAbilityContext, topicId: number): Promise<TopicDetailCache | null> {
    try {
      const rowKey = CacheSettings.topicDetailRowKey(topicId)
      const store = await LocalDataStore.open(context)
      const row = await CacheSettings.loadCacheEntry(context, store, rowKey, CACHE_KIND_TOPIC_DETAIL)
      if (!row) {
        return null
      }
      const parsed = CacheSettings.parseTopicDetail(row.payloadText)
      if (!parsed) {
        await CacheSettings.deleteCacheEntry(context, store, rowKey, CACHE_KIND_TOPIC_DETAIL)
        return null
      }
      await CacheSettings.touchCacheEntry(store, rowKey, CACHE_KIND_TOPIC_DETAIL)
      return parsed
    } catch (error) {
      return null
    }
  }

  static async saveTopicDetail(
    context: common.UIAbilityContext,
    topicId: number,
    topic: V2exTopic | null,
    replies: V2exReply[]
  ): Promise<void> {
    try {
      const now = CacheSettings.nowSeconds()
      const payload: TopicDetailCache = {
        topic: topic,
        replies: replies,
        cachedAt: now
      }
      const store = await LocalDataStore.open(context)
      await CacheSettings.saveCacheEntry(
        context,
        store,
        CacheSettings.topicDetailRowKey(topicId),
        CACHE_KIND_TOPIC_DETAIL,
        topicDetailPayloadFileName(CacheSettings.topicDetailRowKey(topicId)),
        JSON.stringify(payload),
        now,
        now + TOPIC_DETAIL_TTL_SECONDS
      )
      await CacheSettings.pruneCache(context, store, now)
      CacheSettings.deleteLegacyCacheBestEffort(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save detail cache')
    }
  }

  static async loadStats(context: common.UIAbilityContext): Promise<CacheStats> {
    try {
      const now = CacheSettings.nowSeconds()
      const store = await LocalDataStore.open(context)
      await CacheSettings.deleteExpiredRows(context, store, now)
      const resultSet = await store.querySql(SQL_SELECT_CACHE_STATS)
      return CacheSettings.readStatsResult(resultSet)
    } catch (error) {
      return { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await LocalDataStore.open(context)
      await CacheSettings.deleteRowsWithPayloadFiles(
        context,
        store,
        SQL_SELECT_CLEAR_CACHE_PAYLOAD_PATHS,
        [],
        SQL_CLEAR_CACHE_ENTRIES,
        []
      )
      await CacheSettings.deleteOrphanPayloadFiles(context, store)
      CacheSettings.deleteLegacyCacheBestEffort(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_CACHE_CLEAR_FAILED, 'Failed to clear cache'))
    }
  }

  private static async loadCacheEntry(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    cacheKey: string,
    kind: string
  ): Promise<CacheEntry | null> {
    const args: relationalStore.ValueType[] = [cacheKey, kind]
    const resultSet = await store.querySql(SQL_SELECT_CACHE_ENTRY, args)
    try {
      if (!resultSet.goToNextRow()) {
        return null
      }
      const payloadIndex = resultSet.getColumnIndex('payload_text')
      const pathIndex = resultSet.getColumnIndex('payload_path')
      const hashIndex = resultSet.getColumnIndex('payload_hash')
      const expiresIndex = resultSet.getColumnIndex('expires_at')
      const expiresAt = resultSet.getLong(expiresIndex)
      if (expiresAt <= CacheSettings.nowSeconds()) {
        await CacheSettings.deleteCacheEntry(context, store, cacheKey, kind)
        return null
      }
      const payloadText = CacheSettings.readNullableString(resultSet, payloadIndex)
      const payloadPath = CacheSettings.readNullableString(resultSet, pathIndex)
      const storedPayloadHash = CacheSettings.readNullableString(resultSet, hashIndex)
      const resolvedPayload = resolvePayloadText(context, payloadText, payloadPath)
      if (resolvedPayload.length <= 0) {
        await CacheSettings.deleteCacheEntry(context, store, cacheKey, kind)
        return null
      }
      if (storedPayloadHash.length > 0 && payloadHash(resolvedPayload) !== storedPayloadHash) {
        await CacheSettings.deleteCacheEntry(context, store, cacheKey, kind)
        return null
      }
      return {
        payloadText: resolvedPayload,
        payloadPath: payloadPath || '',
        expiresAt: expiresAt
      }
    } finally {
      resultSet.close()
    }
  }

  private static async saveCacheEntry(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    cacheKey: string,
    kind: string,
    payloadFileName: string,
    payloadText: string,
    cachedAt: number,
    expiresAt: number
  ): Promise<void> {
    const previousPayloadPath = await CacheSettings.loadCacheEntryPayloadPath(store, cacheKey, kind)
    const nextPayloadHash = payloadHash(payloadText)
    const payloadPlan = preparePayloadStorage(context, payloadFileName, payloadText)
    const args: relationalStore.ValueType[] = [
      cacheKey,
      kind,
      payloadPlan.payloadText,
      payloadPlan.payloadPath,
      nextPayloadHash,
      cachedAt,
      cachedAt,
      expiresAt,
      payloadPlan.size
    ]
    try {
      commitStagedPayloadFile(context, payloadPlan)
      await store.executeSql(SQL_UPSERT_CACHE_ENTRY, args)
      if (previousPayloadPath && previousPayloadPath !== payloadPlan.payloadPath) {
        unlinkPayloadFileBestEffort(context, previousPayloadPath)
      }
    } catch (error) {
      cleanupPreparedPayloadFile(context, payloadPlan)
      const e = error as Error
      throw new Error(e.message || 'Failed to save cache')
    }
  }

  private static async touchCacheEntry(
    store: relationalStore.RdbStore,
    cacheKey: string,
    kind: string
  ): Promise<void> {
    const args: relationalStore.ValueType[] = [CacheSettings.nowSeconds(), cacheKey, kind]
    await store.executeSql(SQL_TOUCH_CACHE_ENTRY, args)
  }

  private static async deleteCacheEntry(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    cacheKey: string,
    kind: string
  ): Promise<void> {
    const payloadPath = await CacheSettings.loadCacheEntryPayloadPath(store, cacheKey, kind)
    const args: relationalStore.ValueType[] = [cacheKey, kind]
    await store.executeSql(SQL_DELETE_CACHE_ENTRY, args)
    if (payloadPath) {
      unlinkPayloadFileBestEffort(context, payloadPath)
    }
  }

  private static async deleteExpiredRows(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    now: number
  ): Promise<void> {
    const args: relationalStore.ValueType[] = [now]
    await CacheSettings.deleteRowsWithPayloadFiles(
      context,
      store,
      SQL_SELECT_EXPIRED_CACHE_PAYLOAD_PATHS,
      args,
      SQL_DELETE_EXPIRED_CACHE_ENTRIES,
      args
    )
  }

  private static async pruneCache(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    now: number
  ): Promise<void> {
    await CacheSettings.deleteExpiredRows(context, store, now)
    await CacheSettings.deleteRowsWithPayloadFiles(context, store, SQL_SELECT_PRUNE_TOPIC_LIST_PAYLOAD_PATHS, [], SQL_PRUNE_TOPIC_LIST_ROWS, [])
    await CacheSettings.deleteRowsWithPayloadFiles(context, store, SQL_SELECT_PRUNE_TOPIC_DETAIL_PAYLOAD_PATHS, [], SQL_PRUNE_TOPIC_DETAIL_ROWS, [])
    await CacheSettings.pruneCachePayloadSize(context, store)
    await CacheSettings.deleteOrphanPayloadFiles(context, store)
  }

  private static async pruneCachePayloadSize(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore
  ): Promise<void> {
    let totalSize = 0
    const resultSet = await store.querySql(SQL_SELECT_CACHE_PAYLOAD_SIZE)
    try {
      if (resultSet.goToNextRow()) {
        const sizeIndex = resultSet.getColumnIndex('total_size')
        totalSize = resultSet.getLong(sizeIndex)
      }
    } finally {
      resultSet.close()
    }
    while (totalSize > MAX_CACHE_PAYLOAD_SIZE) {
      const args: relationalStore.ValueType[] = [1]
      await CacheSettings.deleteRowsWithPayloadFiles(
        context,
        store,
        SQL_SELECT_PRUNE_CACHE_PAYLOAD_PATHS,
        args,
        SQL_PRUNE_CACHE_PAYLOAD_SIZE,
        args
      )
      totalSize = await CacheSettings.loadCachePayloadSize(store)
    }
  }

  private static async loadCachePayloadSize(store: relationalStore.RdbStore): Promise<number> {
    const resultSet = await store.querySql(SQL_SELECT_CACHE_PAYLOAD_SIZE)
    try {
      if (!resultSet.goToNextRow()) {
        return 0
      }
      const sizeIndex = resultSet.getColumnIndex('total_size')
      return resultSet.getLong(sizeIndex)
    } finally {
      resultSet.close()
    }
  }

  private static async loadCacheEntryPayloadPath(
    store: relationalStore.RdbStore,
    cacheKey: string,
    kind: string
  ): Promise<string> {
    const args: relationalStore.ValueType[] = [cacheKey, kind]
    const resultSet = await store.querySql(SQL_SELECT_CACHE_ENTRY_PAYLOAD_PATH, args)
    try {
      if (!resultSet.goToNextRow()) {
        return ''
      }
      return CacheSettings.readNullableString(resultSet, resultSet.getColumnIndex('payload_path'))
    } finally {
      resultSet.close()
    }
  }

  private static async deleteRowsWithPayloadFiles(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore,
    selectPayloadPathsSql: string,
    selectArgs: relationalStore.ValueType[],
    deleteSql: string,
    deleteArgs: relationalStore.ValueType[]
  ): Promise<void> {
    const payloadPaths = await CacheSettings.selectPayloadPaths(store, selectPayloadPathsSql, selectArgs)
    await store.executeSql(deleteSql, deleteArgs)
    payloadPaths.forEach((payloadPath: string) => {
      unlinkPayloadFileBestEffort(context, payloadPath)
    })
  }

  private static async selectPayloadPaths(
    store: relationalStore.RdbStore,
    sql: string,
    args: relationalStore.ValueType[]
  ): Promise<string[]> {
    const payloadPaths: string[] = []
    const resultSet = await store.querySql(sql, args)
    try {
      const pathIndex = resultSet.getColumnIndex('payload_path')
      while (resultSet.goToNextRow()) {
        const payloadPath = CacheSettings.readNullableString(resultSet, pathIndex)
        if (payloadPath.length > 0) {
          payloadPaths.push(payloadPath)
        }
      }
    } finally {
      resultSet.close()
    }
    return payloadPaths
  }

  private static async deleteOrphanPayloadFiles(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore
  ): Promise<void> {
    const activePaths = new Set<string>(await CacheSettings.selectPayloadPaths(store, SQL_SELECT_ACTIVE_CACHE_PAYLOAD_PATHS, []))
    deleteOrphanPayloadFiles(context, activePaths)
  }

  private static readNullableString(resultSet: relationalStore.ResultSet, columnIndex: number): string {
    if (resultSet.isColumnNull(columnIndex)) {
      return ''
    }
    return resultSet.getString(columnIndex)
  }

  private static readKeyIndexResult(resultSet: relationalStore.ResultSet): CacheKeyIndex {
    const topicLists: string[] = []
    const topicDetails: number[] = []
    let updatedAt = 0
    try {
      const keyIndex = resultSet.getColumnIndex('cache_key')
      const kindIndex = resultSet.getColumnIndex('kind')
      const cachedAtIndex = resultSet.getColumnIndex('cached_at')
      const accessedAtIndex = resultSet.getColumnIndex('accessed_at')
      while (resultSet.goToNextRow()) {
        const cacheKey = resultSet.getString(keyIndex)
        const kind = resultSet.getString(kindIndex)
        updatedAt = Math.max(updatedAt, resultSet.getLong(cachedAtIndex), resultSet.getLong(accessedAtIndex))
        if (kind === CACHE_KIND_TOPIC_LIST && cacheKey.startsWith(KEY_PREFIX_TOPIC_LIST)) {
          topicLists.push(cacheKey.substring(KEY_PREFIX_TOPIC_LIST.length))
        } else if (kind === CACHE_KIND_TOPIC_DETAIL && cacheKey.startsWith(KEY_PREFIX_TOPIC_DETAIL)) {
          const id = parseInt(cacheKey.substring(KEY_PREFIX_TOPIC_DETAIL.length), 10)
          if (Number.isFinite(id) && id > 0) {
            topicDetails.push(id)
          }
        }
      }
    } finally {
      resultSet.close()
    }
    return {
      topicLists: topicLists,
      topicDetails: topicDetails,
      updatedAt: updatedAt
    }
  }

  private static readStatsResult(resultSet: relationalStore.ResultSet): CacheStats {
    let topicListCount = 0
    let topicDetailCount = 0
    let updatedAt = 0
    try {
      const kindIndex = resultSet.getColumnIndex('kind')
      const countIndex = resultSet.getColumnIndex('count_value')
      const updatedAtIndex = resultSet.getColumnIndex('updated_at')
      while (resultSet.goToNextRow()) {
        const kind = resultSet.getString(kindIndex)
        const count = resultSet.getLong(countIndex)
        updatedAt = Math.max(updatedAt, resultSet.getLong(updatedAtIndex))
        if (kind === CACHE_KIND_TOPIC_LIST) {
          topicListCount = count
        } else if (kind === CACHE_KIND_TOPIC_DETAIL) {
          topicDetailCount = count
        }
      }
    } finally {
      resultSet.close()
    }
    return {
      topicListCount: topicListCount,
      topicDetailCount: topicDetailCount,
      updatedAt: updatedAt
    }
  }

  private static parseTopicList(raw: string): V2exTopic[] {
    try {
      const parsed = JSON.parse(raw) as V2exTopic[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: V2exTopic) => item.id > 0 && item.title.length > 0)
    } catch (error) {
      return []
    }
  }

  private static parseTopicDetail(raw: string): TopicDetailCache | null {
    try {
      const parsed = JSON.parse(raw) as TopicDetailCache
      if (!parsed || !Array.isArray(parsed.replies)) {
        return null
      }
      return parsed
    } catch (error) {
      return null
    }
  }

  private static deleteLegacyCacheBestEffort(context: common.UIAbilityContext): void {
    withPreferencesStore<void>(context, STORE_NAME, (store: SettingsPreferencesStore) => {
      const index = CacheSettings.readLegacyIndex(store)
      const keys: string[] = [KEY_CACHE_INDEX]
      index.topicLists.forEach((key: string) => {
        keys.push(KEY_PREFIX_TOPIC_LIST + key)
      })
      index.topicDetails.forEach((key: string) => {
        keys.push(KEY_PREFIX_TOPIC_DETAIL + key)
      })
      deleteKeysAndFlush(store, keys)
    }).catch(() => {})
  }

  private static readLegacyIndex(store: SettingsPreferencesStore): LegacyCacheIndex {
    try {
      const raw = store.getSync(KEY_CACHE_INDEX, '{"topicLists":[],"topicDetails":[],"updatedAt":0}') as string
      const parsed = JSON.parse(raw) as LegacyCacheIndex
      return {
        topicLists: Array.isArray(parsed.topicLists) ? parsed.topicLists : [],
        topicDetails: Array.isArray(parsed.topicDetails) ? parsed.topicDetails : [],
        updatedAt: parsed.updatedAt || 0
      }
    } catch (error) {
      return { topicLists: [], topicDetails: [], updatedAt: 0 }
    }
  }

  private static topicListRowKey(cacheKey: string): string {
    return KEY_PREFIX_TOPIC_LIST + cacheKey
  }

  private static topicDetailRowKey(topicId: number): string {
    return KEY_PREFIX_TOPIC_DETAIL + topicId.toString()
  }

  private static nowSeconds(): number {
    return Math.floor(Date.now() / 1000)
  }
}
