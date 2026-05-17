import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { V2exReply, V2exTopic } from '../network/NetworkTypes'
import { LocalDataStore } from '../storage/LocalDataStore'
import { deleteKeysAndFlush, SettingsPreferencesStore, withPreferencesStore } from './SettingsStorage'
import { STORE_NAME_CACHE } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_CACHE
// Legacy Preferences keys kept for clean-break deletion traceability.
const KEY_PREFIX_TOPIC_LIST: string = 'topicList:'
const KEY_PREFIX_TOPIC_DETAIL: string = 'topicDetail:'
const KEY_CACHE_INDEX: string = 'cacheIndex'

const CACHE_KIND_TOPIC_LIST: string = 'topic_list'
const CACHE_KIND_TOPIC_DETAIL: string = 'topic_detail'
const CACHE_KINDS_SQL: string = `'${CACHE_KIND_TOPIC_LIST}', '${CACHE_KIND_TOPIC_DETAIL}'`

// Offline cache policy. These values are intentionally centralized here so
// callers keep treating AppStorage as UI projection, not durable cache state.
const TOPIC_LIST_TTL_SECONDS: number = 7 * 24 * 60 * 60
const TOPIC_DETAIL_TTL_SECONDS: number = 30 * 24 * 60 * 60
const MAX_TOPIC_LIST_ROWS: number = 32
const MAX_TOPIC_DETAIL_ROWS: number = 200
const FILE_PAYLOAD_THRESHOLD_BYTES: number = 256 * 1024
const MAX_CACHE_PAYLOAD_SIZE: number = 20 * 1024 * 1024
const MAX_TOPIC_LIST_ITEMS: number = 50
const CACHE_PAYLOAD_DIR_NAME: string = 'cache_payloads'
const CACHE_PAYLOAD_TOPIC_LIST_PREFIX: string = 'topic_list_'
const CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX: string = 'topic_detail_'
const CACHE_PAYLOAD_FILE_SUFFIX: string = '.json'
const CACHE_PAYLOAD_STAGED_SUFFIX: string = '.staged'
const MAX_CACHE_PAYLOAD_FILENAME_STEM_LENGTH: number = 180

const SQL_SELECT_CACHE_ENTRY: string = 'SELECT payload_text, payload_path, expires_at FROM cache_entries WHERE cache_key = ? AND kind = ? LIMIT 1'
const SQL_SELECT_CACHE_INDEX: string = `SELECT cache_key, kind, cached_at, accessed_at FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) ORDER BY cached_at DESC`
const SQL_SELECT_CACHE_STATS: string = `SELECT kind, COUNT(*) AS count_value, MAX(cached_at) AS updated_at FROM cache_entries WHERE kind IN (${CACHE_KINDS_SQL}) GROUP BY kind`
const SQL_UPSERT_CACHE_ENTRY: string = 'INSERT OR REPLACE INTO cache_entries (cache_key, kind, payload_text, payload_path, cached_at, accessed_at, expires_at, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
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

interface PayloadStoragePlan {
  payloadText: string | null
  payloadPath: string | null
  stagedPayloadPath: string | null
  size: number
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
        CacheSettings.topicListPayloadFileName(CacheSettings.topicListRowKey(cacheKey)),
        payload,
        now,
        now + TOPIC_LIST_TTL_SECONDS
      )
      await CacheSettings.pruneCache(context, store, now)
      CacheSettings.deleteLegacyCacheBestEffort(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存列表缓存失败')
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
        CacheSettings.topicDetailPayloadFileName(CacheSettings.topicDetailRowKey(topicId)),
        JSON.stringify(payload),
        now,
        now + TOPIC_DETAIL_TTL_SECONDS
      )
      await CacheSettings.pruneCache(context, store, now)
      CacheSettings.deleteLegacyCacheBestEffort(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存详情缓存失败')
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
      throw new Error(e.message || '清理缓存失败')
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
      const expiresIndex = resultSet.getColumnIndex('expires_at')
      const expiresAt = resultSet.getLong(expiresIndex)
      if (expiresAt <= CacheSettings.nowSeconds()) {
        await CacheSettings.deleteCacheEntry(context, store, cacheKey, kind)
        return null
      }
      const payloadText = CacheSettings.readNullableString(resultSet, payloadIndex)
      const payloadPath = CacheSettings.readNullableString(resultSet, pathIndex)
      const resolvedPayload = CacheSettings.resolvePayloadText(context, payloadText, payloadPath)
      if (resolvedPayload.length <= 0) {
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
    const payloadPlan = CacheSettings.preparePayloadStorage(context, payloadFileName, payloadText)
    const args: relationalStore.ValueType[] = [
      cacheKey,
      kind,
      payloadPlan.payloadText,
      payloadPlan.payloadPath,
      cachedAt,
      cachedAt,
      expiresAt,
      payloadPlan.size
    ]
    try {
      CacheSettings.commitStagedPayloadFile(context, payloadPlan)
      await store.executeSql(SQL_UPSERT_CACHE_ENTRY, args)
      if (previousPayloadPath && previousPayloadPath !== payloadPlan.payloadPath) {
        CacheSettings.unlinkPayloadFileBestEffort(context, previousPayloadPath)
      }
    } catch (error) {
      CacheSettings.cleanupPreparedPayloadFile(context, payloadPlan)
      const e = error as Error
      throw new Error(e.message || '保存缓存失败')
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
      CacheSettings.unlinkPayloadFileBestEffort(context, payloadPath)
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
      CacheSettings.unlinkPayloadFileBestEffort(context, payloadPath)
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

  private static preparePayloadStorage(
    context: common.UIAbilityContext,
    payloadFileName: string,
    payloadText: string
  ): PayloadStoragePlan {
    const size = CacheSettings.byteLength(payloadText)
    if (size < FILE_PAYLOAD_THRESHOLD_BYTES) {
      return {
        payloadText: payloadText,
        payloadPath: null,
        stagedPayloadPath: null,
        size: size
      }
    }
    CacheSettings.ensurePayloadDirectory(context)
    const committedPayloadFileName = CacheSettings.committedPayloadFileName(context, payloadFileName)
    const stagedPayloadFileName = CacheSettings.stagedPayloadFileName(committedPayloadFileName)
    CacheSettings.writePayloadFile(context, stagedPayloadFileName, payloadText)
    return {
      payloadText: null,
      payloadPath: committedPayloadFileName,
      stagedPayloadPath: stagedPayloadFileName,
      size: size
    }
  }

  private static commitStagedPayloadFile(context: common.UIAbilityContext, payloadPlan: PayloadStoragePlan): void {
    if (!payloadPlan.stagedPayloadPath || !payloadPlan.payloadPath) {
      return
    }
    try {
      fileIo.renameSync(
        CacheSettings.payloadFilePath(context, payloadPlan.stagedPayloadPath),
        CacheSettings.payloadFilePath(context, payloadPlan.payloadPath)
      )
    } catch (error) {
      CacheSettings.cleanupPreparedPayloadFile(context, payloadPlan)
      const e = error as Error
      throw new Error(e.message || '提交缓存文件失败')
    }
  }

  private static cleanupPreparedPayloadFile(context: common.UIAbilityContext, payloadPlan: PayloadStoragePlan): void {
    if (payloadPlan.stagedPayloadPath) {
      CacheSettings.unlinkPayloadFileBestEffort(context, payloadPlan.stagedPayloadPath)
    }
    if (payloadPlan.payloadPath) {
      CacheSettings.unlinkPayloadFileBestEffort(context, payloadPlan.payloadPath)
    }
  }

  private static resolvePayloadText(
    context: common.UIAbilityContext,
    payloadText: string,
    payloadPath: string
  ): string {
    if (payloadPath.length > 0 && CacheSettings.isCachePayloadFileName(payloadPath)) {
      try {
        return fileIo.readTextSync(CacheSettings.payloadFilePath(context, payloadPath))
      } catch (_error) {
      }
    }
    return payloadText
  }

  private static ensurePayloadDirectory(context: common.UIAbilityContext): void {
    try {
      fileIo.mkdirSync(CacheSettings.payloadBaseDir(context), true)
    } catch (_error) {
    }
  }

  private static writePayloadFile(context: common.UIAbilityContext, relativeName: string, payloadText: string): void {
    if (!CacheSettings.isSafePayloadFileName(relativeName)) {
      throw new Error('非法缓存文件名')
    }
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        CacheSettings.payloadFilePath(context, relativeName),
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )
      fileIo.writeSync(file.fd, payloadText)
    } finally {
      CacheSettings.closeFileBestEffort(file)
    }
  }

  private static async deleteOrphanPayloadFiles(
    context: common.UIAbilityContext,
    store: relationalStore.RdbStore
  ): Promise<void> {
    let filenames: string[] = []
    try {
      filenames = fileIo.listFileSync(CacheSettings.payloadBaseDir(context))
    } catch (_error) {
      return
    }
    const activePaths = new Set<string>(await CacheSettings.selectPayloadPaths(store, SQL_SELECT_ACTIVE_CACHE_PAYLOAD_PATHS, []))
    filenames.forEach((filename: string) => {
      if (
        CacheSettings.isCachePayloadArtifactFileName(filename) &&
        !activePaths.has(filename)
      ) {
        CacheSettings.unlinkPayloadFileBestEffort(context, filename)
      }
    })
  }

  private static unlinkPayloadFileBestEffort(context: common.UIAbilityContext, relativeName: string): void {
    if (!CacheSettings.isSafePayloadFileName(relativeName)) {
      return
    }
    try {
      fileIo.unlinkSync(CacheSettings.payloadFilePath(context, relativeName))
    } catch (_error) {
    }
  }

  private static closeFileBestEffort(file: fileIo.File | null): void {
    if (!file) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (_error) {
    }
  }

  private static readNullableString(resultSet: relationalStore.ResultSet, columnIndex: number): string {
    if (resultSet.isColumnNull(columnIndex)) {
      return ''
    }
    return resultSet.getString(columnIndex)
  }

  private static topicListPayloadFileName(rowKey: string): string {
    return CACHE_PAYLOAD_TOPIC_LIST_PREFIX + CacheSettings.encodePayloadKey(rowKey) + CACHE_PAYLOAD_FILE_SUFFIX
  }

  private static topicDetailPayloadFileName(rowKey: string): string {
    return CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX + CacheSettings.encodePayloadKey(rowKey) + CACHE_PAYLOAD_FILE_SUFFIX
  }

  private static committedPayloadFileName(context: common.UIAbilityContext, baseName: string): string {
    if (!CacheSettings.isCachePayloadFileName(baseName)) {
      throw new Error('非法缓存文件名')
    }
    const stem = baseName.substring(0, baseName.length - CACHE_PAYLOAD_FILE_SUFFIX.length)
    for (let attempt = 0; attempt < 8; attempt++) {
      const candidate = stem + '_' + Date.now().toString() + '_' + CacheSettings.randomPayloadNonce() + CACHE_PAYLOAD_FILE_SUFFIX
      if (!CacheSettings.payloadFileExistsBestEffort(context, candidate)) {
        return candidate
      }
    }
    throw new Error('缓存文件名冲突')
  }

  private static stagedPayloadFileName(committedName: string): string {
    if (!CacheSettings.isCachePayloadFileName(committedName)) {
      throw new Error('非法缓存文件名')
    }
    return committedName + CACHE_PAYLOAD_STAGED_SUFFIX
  }

  private static randomPayloadNonce(): string {
    return Math.floor(Math.random() * 0x100000000).toString(16).padStart(8, '0')
  }

  private static encodePayloadKey(value: string): string {
    let encoded = ''
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i)
      if (code <= 0x7F) {
        encoded += CacheSettings.hexByte(code)
      } else if (code <= 0x7FF) {
        encoded += CacheSettings.hexByte(0xC0 | (code >> 6))
        encoded += CacheSettings.hexByte(0x80 | (code & 0x3F))
      } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
        const next = value.charCodeAt(i + 1)
        if (next >= 0xDC00 && next <= 0xDFFF) {
          const point = 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00)
          encoded += CacheSettings.hexByte(0xF0 | (point >> 18))
          encoded += CacheSettings.hexByte(0x80 | ((point >> 12) & 0x3F))
          encoded += CacheSettings.hexByte(0x80 | ((point >> 6) & 0x3F))
          encoded += CacheSettings.hexByte(0x80 | (point & 0x3F))
          i += 1
        } else {
          encoded += CacheSettings.hexByte(0xEF)
          encoded += CacheSettings.hexByte(0xBF)
          encoded += CacheSettings.hexByte(0xBD)
        }
      } else {
        encoded += CacheSettings.hexByte(0xE0 | (code >> 12))
        encoded += CacheSettings.hexByte(0x80 | ((code >> 6) & 0x3F))
        encoded += CacheSettings.hexByte(0x80 | (code & 0x3F))
      }
    }
    if (encoded.length <= 0 || encoded.length > MAX_CACHE_PAYLOAD_FILENAME_STEM_LENGTH) {
      throw new Error('缓存文件名长度无效')
    }
    return encoded
  }

  private static hexByte(value: number): string {
    const clean = value & 0xFF
    return clean.toString(16).padStart(2, '0')
  }

  private static payloadBaseDir(context: common.UIAbilityContext): string {
    return context.filesDir + '/' + CACHE_PAYLOAD_DIR_NAME
  }

  private static payloadFilePath(context: common.UIAbilityContext, relativeName: string): string {
    return CacheSettings.payloadBaseDir(context) + '/' + relativeName
  }

  private static payloadFileExistsBestEffort(context: common.UIAbilityContext, relativeName: string): boolean {
    if (!CacheSettings.isSafePayloadFileName(relativeName)) {
      return true
    }
    try {
      return fileIo.accessSync(CacheSettings.payloadFilePath(context, relativeName))
    } catch (_error) {
      return false
    }
  }

  private static isCachePayloadFileName(relativeName: string): boolean {
    return (
      relativeName.startsWith(CACHE_PAYLOAD_TOPIC_LIST_PREFIX) ||
      relativeName.startsWith(CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX)
    ) && relativeName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX) &&
      !relativeName.includes(CACHE_PAYLOAD_STAGED_SUFFIX) &&
      CacheSettings.isSafePayloadFileName(relativeName)
  }

  private static isCachePayloadArtifactFileName(relativeName: string): boolean {
    if (CacheSettings.isCachePayloadFileName(relativeName)) {
      return true
    }
    if (!relativeName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX + CACHE_PAYLOAD_STAGED_SUFFIX)) {
      return false
    }
    return CacheSettings.isCachePayloadFileName(relativeName.substring(0, relativeName.length - CACHE_PAYLOAD_STAGED_SUFFIX.length))
  }

  private static isSafePayloadFileName(relativeName: string): boolean {
    if (
      relativeName.length <= 0 ||
      relativeName.startsWith('.') ||
      relativeName.includes('/') ||
      relativeName.includes('\\') ||
      relativeName.includes('..')
    ) {
      return false
    }
    return /^[A-Za-z0-9._-]+$/.test(relativeName)
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

  private static byteLength(value: string): number {
    let bytes = 0
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i)
      if (code <= 0x7F) {
        bytes += 1
      } else if (code <= 0x7FF) {
        bytes += 2
      } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
        const next = value.charCodeAt(i + 1)
        if (next >= 0xDC00 && next <= 0xDFFF) {
          bytes += 4
          i += 1
        } else {
          bytes += 3
        }
      } else {
        bytes += 3
      }
    }
    return bytes
  }
}
