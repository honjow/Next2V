import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { HttpClient } from '../network/HttpClient'
import { StorageKeys } from '../constants/StorageKeys'
import { V2exTabParser, type V2exBlockedIdLists } from '../parser/V2exTabParser'
import { AccountStore } from './AccountStore'
import { STORE_NAME_SETTINGS, setAppStorageValue } from './SettingsStorage'

const KEY_PREFIX: string = 'blockedListState:'

export interface BlockedListSnapshot {
  ignoredTopicIds: number[]
  blockedMemberIds: number[]
  ownerKey: string
  updatedAt: number
}

export interface BlockedListCaptureSource {
  endpoint?: string
  source?: string
  trigger?: string
  statusCode?: number
  locationType?: string
  bodyLength?: number
  hasCookie?: boolean
  hasUsername?: boolean
}

interface BlockedListOwnerLogContext {
  ownerKeyPresent: boolean
  ownerKeyHash: string
}

interface BlockedListSnapshotLogContext extends BlockedListOwnerLogContext {
  ignored_count: number
  blocked_count: number
  updatedAt: number
}

interface BlockedListCacheLogContext extends BlockedListSnapshotLogContext {
  cacheHit: boolean
}

interface BlockedListSourceLogContext extends BlockedListCaptureSource {
  endpoint: string
  source: string
  trigger: string
  statusCode: number
  locationType: string
  bodyLength: number
  hasCookie: boolean
  hasUsername: boolean
}

interface BlockedListSourceOwnerLogContext extends BlockedListSourceLogContext, BlockedListOwnerLogContext {}
interface BlockedListSourceSnapshotLogContext extends BlockedListSourceLogContext, BlockedListSnapshotLogContext {}

interface BlockedListExtractLogContext extends BlockedListSourceLogContext {
  ignored_topics_present: boolean
  blocked_present: boolean
  ignored_count: number
  blocked_count: number
  ignoredRawLength: number
  blockedRawLength: number
}

interface BlockedListMissingVariablesLogContext extends BlockedListSourceLogContext {
  missingIgnoredTopics: boolean
  missingBlockedMembers: boolean
}

export class BlockedListSettings {
  private static context: common.UIAbilityContext | null = null

  static setContext(context: common.UIAbilityContext): void {
    BlockedListSettings.context = context
  }

  static empty(ownerKey: string = ''): BlockedListSnapshot {
    return { ignoredTopicIds: [], blockedMemberIds: [], ownerKey: ownerKey, updatedAt: 0 }
  }

  static runtimeSnapshot(): BlockedListSnapshot {
    const ownerKey = AppStorage.get<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY) || ''
    if (!ownerKey || ownerKey !== BlockedListSettings.activeOwnerKey()) {
      return BlockedListSettings.empty(BlockedListSettings.activeOwnerKey())
    }
    return BlockedListSettings.normalize({
      ignoredTopicIds: BlockedListSettings.parseRuntimeIds(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS),
      blockedMemberIds: BlockedListSettings.parseRuntimeIds(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS),
      ownerKey: ownerKey,
      updatedAt: AppStorage.get<number>(StorageKeys.BLOCKED_LIST_UPDATED_AT) || 0,
    }, ownerKey)
  }

  static activeOwnerKey(): string {
    const activeId = (AppStorage.get<string>(StorageKeys.ACTIVE_ACCOUNT_ID) || AccountStore.getActiveId() || '').trim()
    const username = (AppStorage.get<string>(StorageKeys.AUTH_SESSION_USERNAME) || '').trim()
    const baseUrl = HttpClient.getInstance().getBaseUrl()
    if (activeId) {
      return `${baseUrl}#account:${activeId}`
    }
    if (username) {
      return `${baseUrl}#user:${username}`
    }
    return ''
  }

  static async loadActive(context?: common.UIAbilityContext): Promise<BlockedListSnapshot> {
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      const empty = BlockedListSettings.empty('')
      DiagnosticLogger.info('storage', 'blocked_list_load_cache_result', BlockedListSettings.cacheLogContext(empty, false))
      return empty
    }
    const ctx = context || BlockedListSettings.context
    if (!ctx) {
      const empty = BlockedListSettings.empty(ownerKey)
      DiagnosticLogger.info('storage', 'blocked_list_load_cache_result', BlockedListSettings.cacheLogContext(empty, false))
      return empty
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      const raw = store.getSync(KEY_PREFIX + ownerKey, '') as string
      if (!raw) {
        const empty = BlockedListSettings.empty(ownerKey)
        DiagnosticLogger.info('storage', 'blocked_list_load_cache_result', BlockedListSettings.cacheLogContext(empty, false))
        return empty
      }
      const parsed = JSON.parse(raw) as BlockedListSnapshot
      const normalized = BlockedListSettings.normalize(parsed, ownerKey)
      DiagnosticLogger.info('storage', 'blocked_list_load_cache_result', BlockedListSettings.cacheLogContext(normalized, true))
      return normalized
    } catch (error) {
      const empty = BlockedListSettings.empty(ownerKey)
      DiagnosticLogger.exception('storage', 'blocked_list_load_exception', error as Error, BlockedListSettings.ownerLogContext(ownerKey))
      DiagnosticLogger.info('storage', 'blocked_list_load_cache_result', BlockedListSettings.cacheLogContext(empty, false))
      return empty
    }
  }

  static async saveActive(snapshot: V2exBlockedIdLists, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      DiagnosticLogger.info('storage', 'blocked_list_skip_save_no_owner', BlockedListSettings.sourceOwnerLogContext(source, ownerKey))
      return
    }
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: snapshot.ignoredTopicIds,
      blockedMemberIds: snapshot.blockedMemberIds,
      ownerKey: ownerKey,
      updatedAt: Date.now(),
    }, ownerKey)
    DiagnosticLogger.info('storage', 'blocked_list_save_start', BlockedListSettings.sourceSnapshotLogContext(source, normalized))
    BlockedListSettings.apply(normalized)
    const ctx = context || BlockedListSettings.context
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'blocked_list_no_context_runtime_only', BlockedListSettings.sourceSnapshotLogContext(source, normalized))
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))
      store.flushSync()
      DiagnosticLogger.info('storage', 'blocked_list_save_success', BlockedListSettings.sourceSnapshotLogContext(source, normalized))
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_list_save_exception', error as Error, BlockedListSettings.sourceSnapshotLogContext(source, normalized))
    }
  }

  static updateFromTopicListHtml(html: string, source: BlockedListCaptureSource = {}): boolean {
    const lists = V2exTabParser.extractBlockedIdLists(html || '')
    const sourceContext = BlockedListSettings.sourceLogContext(source)
    DiagnosticLogger.info('network', 'blocked_list_extract_result', BlockedListSettings.extractLogContext(source, lists))
    if (!lists.ignoredTopicsPresent || !lists.blockedMembersPresent) {
      DiagnosticLogger.info('network', 'blocked_list_skip_missing_variables', BlockedListSettings.missingVariablesLogContext(source, lists))
      return false
    }
    BlockedListSettings.saveActive(lists, undefined, sourceContext).catch((error: Error) => {
      DiagnosticLogger.exception('storage', 'blocked_list_save_from_html_exception', error, BlockedListSettings.sourceLogContext(source))
    })
    return true
  }

  static apply(snapshot: BlockedListSnapshot): void {
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY, snapshot.ownerKey)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS, JSON.stringify(snapshot.ignoredTopicIds))
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS, JSON.stringify(snapshot.blockedMemberIds))
    setAppStorageValue<number>(StorageKeys.BLOCKED_LIST_UPDATED_AT, snapshot.updatedAt)
  }

  private static sourceLogContext(source: BlockedListCaptureSource): BlockedListSourceLogContext {
    return {
      endpoint: source.endpoint || '',
      source: source.source || '',
      trigger: source.trigger || '',
      statusCode: source.statusCode || 0,
      locationType: source.locationType || '',
      bodyLength: source.bodyLength || 0,
      hasCookie: !!source.hasCookie,
      hasUsername: !!source.hasUsername,
    }
  }

  private static ownerLogContext(ownerKey: string): BlockedListOwnerLogContext {
    return {
      ownerKeyPresent: !!ownerKey,
      ownerKeyHash: ownerKey ? DiagnosticLogger.ownerHash(ownerKey) : '',
    }
  }

  private static snapshotLogContext(snapshot: BlockedListSnapshot): BlockedListSnapshotLogContext {
    return {
      ownerKeyPresent: !!snapshot.ownerKey,
      ownerKeyHash: snapshot.ownerKey ? DiagnosticLogger.ownerHash(snapshot.ownerKey) : '',
      ignored_count: snapshot.ignoredTopicIds.length,
      blocked_count: snapshot.blockedMemberIds.length,
      updatedAt: snapshot.updatedAt || 0,
    }
  }

  private static cacheLogContext(snapshot: BlockedListSnapshot, cacheHit: boolean): BlockedListCacheLogContext {
    return {
      ownerKeyPresent: !!snapshot.ownerKey,
      ownerKeyHash: snapshot.ownerKey ? DiagnosticLogger.ownerHash(snapshot.ownerKey) : '',
      ignored_count: snapshot.ignoredTopicIds.length,
      blocked_count: snapshot.blockedMemberIds.length,
      updatedAt: snapshot.updatedAt || 0,
      cacheHit: cacheHit,
    }
  }

  private static sourceOwnerLogContext(source: BlockedListCaptureSource, ownerKey: string): BlockedListSourceOwnerLogContext {
    const sourceContext = BlockedListSettings.sourceLogContext(source)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      ownerKeyPresent: !!ownerKey,
      ownerKeyHash: ownerKey ? DiagnosticLogger.ownerHash(ownerKey) : '',
    }
  }

  private static sourceSnapshotLogContext(source: BlockedListCaptureSource, snapshot: BlockedListSnapshot): BlockedListSourceSnapshotLogContext {
    const sourceContext = BlockedListSettings.sourceLogContext(source)
    const snapshotContext = BlockedListSettings.snapshotLogContext(snapshot)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      ownerKeyPresent: snapshotContext.ownerKeyPresent,
      ownerKeyHash: snapshotContext.ownerKeyHash,
      ignored_count: snapshotContext.ignored_count,
      blocked_count: snapshotContext.blocked_count,
      updatedAt: snapshotContext.updatedAt,
    }
  }

  private static extractLogContext(source: BlockedListCaptureSource, lists: V2exBlockedIdLists): BlockedListExtractLogContext {
    const sourceContext = BlockedListSettings.sourceLogContext(source)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      ignored_topics_present: lists.ignoredTopicsPresent,
      blocked_present: lists.blockedMembersPresent,
      ignored_count: lists.ignoredTopicIds.length,
      blocked_count: lists.blockedMemberIds.length,
      ignoredRawLength: lists.ignoredRawLength,
      blockedRawLength: lists.blockedRawLength,
    }
  }

  private static missingVariablesLogContext(source: BlockedListCaptureSource, lists: V2exBlockedIdLists): BlockedListMissingVariablesLogContext {
    const sourceContext = BlockedListSettings.sourceLogContext(source)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      missingIgnoredTopics: !lists.ignoredTopicsPresent,
      missingBlockedMembers: !lists.blockedMembersPresent,
    }
  }

  private static normalize(value: BlockedListSnapshot, ownerKey: string): BlockedListSnapshot {
    return {
      ignoredTopicIds: BlockedListSettings.normalizeIds(value.ignoredTopicIds),
      blockedMemberIds: BlockedListSettings.normalizeIds(value.blockedMemberIds),
      ownerKey: ownerKey,
      updatedAt: Number.isFinite(value.updatedAt) ? value.updatedAt : 0,
    }
  }

  private static normalizeIds(values: number[]): number[] {
    const result: number[] = []
    const seen: Set<number> = new Set()
    const source = Array.isArray(values) ? values : []
    for (const value of source) {
      const id = Math.floor(value)
      if (id > 0 && !seen.has(id)) {
        result.push(id)
        seen.add(id)
      }
    }
    return result
  }

  private static parseRuntimeIds(key: string): number[] {
    try {
      const values = JSON.parse(AppStorage.get<string>(key) || '[]') as number[]
      return Array.isArray(values) ? values : []
    } catch (_error) {
      return []
    }
  }
}
