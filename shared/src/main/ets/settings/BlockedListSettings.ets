import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { HttpClient } from '../network/HttpClient'
import { StorageKeys } from '../constants/StorageKeys'
import { V2exTabParser, type V2exBlockedIdLists } from '../parser/V2exTabParser'
import { AccountStore } from './AccountStore'
import { STORE_NAME_SETTINGS, setAppStorageValue } from './SettingsStorage'

const KEY_PREFIX: string = 'blockedListState:'

export interface BlockedMemberMeta {
  id: number
  username: string
  tagline: string
  avatar: string
  created: number
  updatedAt: number
}

export interface BlockedListSnapshot {
  ignoredTopicIds: number[]
  blockedMemberIds: number[]
  blockedMemberMetas: BlockedMemberMeta[]
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
  blocked_member_meta_count: number
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

interface BlockedListDeltaLogContext extends BlockedListSourceSnapshotLogContext {
  deltaType: string
  targetId: number
  deltaValue: boolean
}

interface BlockedListDeltaOwnerLogContext extends BlockedListSourceOwnerLogContext {
  deltaType: string
  targetId: number
  deltaValue: boolean
}

interface BlockedMemberMetaLogContext extends BlockedListOwnerLogContext {
  memberId: number
  blocked_member_meta_count: number
  usernamePresent: boolean
  avatarPresent: boolean
  taglinePresent: boolean
}

export class BlockedListSettings {
  private static context: common.UIAbilityContext | null = null
  private static snapshotWriteQueue: Promise<void> = Promise.resolve()

  static setContext(context: common.UIAbilityContext): void {
    BlockedListSettings.context = context
  }

  private static enqueueSnapshotWrite(action: () => Promise<void>): Promise<void> {
    const task = BlockedListSettings.snapshotWriteQueue.then(action)
    BlockedListSettings.snapshotWriteQueue = task.catch((_error: Error) => {})
    return task
  }

  static empty(ownerKey: string = ''): BlockedListSnapshot {
    return { ignoredTopicIds: [], blockedMemberIds: [], blockedMemberMetas: [], ownerKey: ownerKey, updatedAt: 0 }
  }

  static runtimeSnapshot(): BlockedListSnapshot {
    const ownerKey = AppStorage.get<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY) || ''
    if (!ownerKey || ownerKey !== BlockedListSettings.activeOwnerKey()) {
      return BlockedListSettings.empty(BlockedListSettings.activeOwnerKey())
    }
    return BlockedListSettings.normalize({
      ignoredTopicIds: BlockedListSettings.parseRuntimeIds(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS),
      blockedMemberIds: BlockedListSettings.parseRuntimeIds(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS),
      blockedMemberMetas: BlockedListSettings.parseRuntimeMemberMetas(),
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
    const ctx = context || BlockedListSettings.context
    const runtime = BlockedListSettings.runtimeSnapshot()
    const runtimeMetas = runtime.ownerKey === ownerKey ? runtime.blockedMemberMetas : []
    const immediate = BlockedListSettings.normalize({
      ignoredTopicIds: snapshot.ignoredTopicIds,
      blockedMemberIds: snapshot.blockedMemberIds,
      blockedMemberMetas: runtimeMetas,
      ownerKey: ownerKey,
      updatedAt: Date.now(),
    }, ownerKey)
    DiagnosticLogger.info('storage', 'blocked_list_save_start', BlockedListSettings.sourceSnapshotLogContext(source, immediate))
    BlockedListSettings.apply(immediate)
    return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.persistSavedSnapshot(immediate, ctx, source))
  }

  private static async persistSavedSnapshot(immediate: BlockedListSnapshot, ctx: common.UIAbilityContext | null, source: BlockedListCaptureSource): Promise<void> {
    const cached = ctx ? await BlockedListSettings.loadSnapshotForOwner(ctx, immediate.ownerKey) : BlockedListSettings.empty(immediate.ownerKey)
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: immediate.ignoredTopicIds,
      blockedMemberIds: immediate.blockedMemberIds,
      blockedMemberMetas: cached.blockedMemberMetas.concat(immediate.blockedMemberMetas),
      ownerKey: immediate.ownerKey,
      updatedAt: immediate.updatedAt,
    }, immediate.ownerKey)
    if (BlockedListSettings.activeOwnerKey() === immediate.ownerKey) {
      BlockedListSettings.apply(normalized)
    }
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'blocked_list_no_context_runtime_only', BlockedListSettings.sourceSnapshotLogContext(source, normalized))
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + immediate.ownerKey, JSON.stringify(normalized))
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

  static async applyIgnoredTopicDelta(topicId: number, ignored: boolean, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    await BlockedListSettings.applyIdDelta('ignored_topic', topicId, ignored, context, source)
  }

  static async applyBlockedMemberDelta(memberId: number, blocked: boolean, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    await BlockedListSettings.applyIdDelta('blocked_member', memberId, blocked, context, source)
  }

  static async upsertBlockedMemberMeta(meta: BlockedMemberMeta, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      DiagnosticLogger.info('storage', 'blocked_member_meta_skip_no_owner', BlockedListSettings.memberMetaLogContext(ownerKey, meta, 0))
      return
    }
    const normalizedMeta = BlockedListSettings.normalizeMemberMeta(meta)
    if (normalizedMeta.id <= 0) {
      DiagnosticLogger.warn('storage', 'blocked_member_meta_skip_invalid_id', BlockedListSettings.memberMetaLogContext(ownerKey, normalizedMeta, 0))
      return
    }
    return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.upsertBlockedMemberMetaLocked(ownerKey, normalizedMeta, context, source))
  }

  private static async upsertBlockedMemberMetaLocked(ownerKey: string, normalizedMeta: BlockedMemberMeta, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    const ctx = context || BlockedListSettings.context
    const base = await BlockedListSettings.snapshotForOwnerWrite(ctx, ownerKey)
    if (base.blockedMemberIds.indexOf(normalizedMeta.id) < 0) {
      DiagnosticLogger.info('storage', 'blocked_member_meta_skip_not_blocked', BlockedListSettings.memberMetaLogContext(ownerKey, normalizedMeta, base.blockedMemberMetas.length))
      return
    }
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: base.ignoredTopicIds,
      blockedMemberIds: base.blockedMemberIds,
      blockedMemberMetas: BlockedListSettings.upsertMemberMeta(base.blockedMemberMetas, normalizedMeta),
      ownerKey: ownerKey,
      updatedAt: base.updatedAt,
    }, ownerKey)
    if (BlockedListSettings.activeOwnerKey() === ownerKey) {
      setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS, JSON.stringify(normalized.blockedMemberMetas))
    }
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'blocked_member_meta_no_context_runtime_only', BlockedListSettings.memberMetaLogContext(ownerKey, normalizedMeta, normalized.blockedMemberMetas.length))
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))
      store.flushSync()
      DiagnosticLogger.info('storage', 'blocked_member_meta_upsert_success', BlockedListSettings.memberMetaLogContext(ownerKey, normalizedMeta, normalized.blockedMemberMetas.length))
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_member_meta_upsert_exception', error as Error, BlockedListSettings.memberMetaLogContext(ownerKey, normalizedMeta, normalized.blockedMemberMetas.length))
    }
  }

  static apply(snapshot: BlockedListSnapshot): void {
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY, snapshot.ownerKey)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS, JSON.stringify(snapshot.ignoredTopicIds))
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS, JSON.stringify(snapshot.blockedMemberIds))
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS, JSON.stringify(snapshot.blockedMemberMetas))
    setAppStorageValue<number>(StorageKeys.BLOCKED_LIST_UPDATED_AT, snapshot.updatedAt)
  }

  private static async applyIdDelta(
    deltaType: string,
    targetId: number,
    deltaValue: boolean,
    context?: common.UIAbilityContext,
    source: BlockedListCaptureSource = {},
  ): Promise<void> {
    const normalizedId = Math.floor(targetId)
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      DiagnosticLogger.info('storage', 'blocked_list_delta_skip_no_owner', BlockedListSettings.deltaOwnerLogContext(source, ownerKey, deltaType, normalizedId, deltaValue))
      return
    }
    if (normalizedId <= 0) {
      DiagnosticLogger.warn('storage', 'blocked_list_delta_skip_invalid_id', BlockedListSettings.deltaOwnerLogContext(source, ownerKey, deltaType, normalizedId, deltaValue))
      return
    }

    const ctx = context || BlockedListSettings.context
    const runtime = BlockedListSettings.runtimeSnapshot()
    const base = runtime.ownerKey === ownerKey ? runtime : BlockedListSettings.empty(ownerKey)
    const immediate = BlockedListSettings.normalize(BlockedListSettings.nextDeltaSnapshot(base, deltaType, normalizedId, deltaValue, ownerKey), ownerKey)
    DiagnosticLogger.info('storage', 'blocked_list_delta_start', BlockedListSettings.deltaSnapshotLogContext(source, immediate, deltaType, normalizedId, deltaValue))
    BlockedListSettings.apply(immediate)
    return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.applyIdDeltaLocked(immediate, ctx, source, deltaType, normalizedId, deltaValue))
  }

  private static async applyIdDeltaLocked(
    immediate: BlockedListSnapshot,
    ctx: common.UIAbilityContext | null,
    source: BlockedListCaptureSource,
    deltaType: string,
    normalizedId: number,
    deltaValue: boolean,
  ): Promise<void> {
    const cached = ctx ? await BlockedListSettings.loadSnapshotForOwner(ctx, immediate.ownerKey) : BlockedListSettings.empty(immediate.ownerKey)
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: immediate.ignoredTopicIds,
      blockedMemberIds: immediate.blockedMemberIds,
      blockedMemberMetas: cached.blockedMemberMetas.concat(immediate.blockedMemberMetas),
      ownerKey: immediate.ownerKey,
      updatedAt: immediate.updatedAt,
    }, immediate.ownerKey)
    if (BlockedListSettings.activeOwnerKey() === immediate.ownerKey) {
      BlockedListSettings.apply(normalized)
    }
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'blocked_list_delta_no_context_runtime_only', BlockedListSettings.deltaSnapshotLogContext(source, normalized, deltaType, normalizedId, deltaValue))
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + immediate.ownerKey, JSON.stringify(normalized))
      store.flushSync()
      DiagnosticLogger.info('storage', 'blocked_list_delta_success', BlockedListSettings.deltaSnapshotLogContext(source, normalized, deltaType, normalizedId, deltaValue))
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_list_delta_save_exception', error as Error, BlockedListSettings.deltaSnapshotLogContext(source, normalized, deltaType, normalizedId, deltaValue))
    }
  }

  private static async loadSnapshotForOwner(ctx: common.UIAbilityContext, ownerKey: string): Promise<BlockedListSnapshot> {
    if (!ownerKey) {
      return BlockedListSettings.empty('')
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      const raw = store.getSync(KEY_PREFIX + ownerKey, '') as string
      if (!raw) {
        return BlockedListSettings.empty(ownerKey)
      }
      return BlockedListSettings.normalize(JSON.parse(raw) as BlockedListSnapshot, ownerKey)
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_list_load_owner_exception', error as Error, BlockedListSettings.ownerLogContext(ownerKey))
      return BlockedListSettings.empty(ownerKey)
    }
  }

  private static async snapshotForOwnerWrite(ctx: common.UIAbilityContext | null, ownerKey: string): Promise<BlockedListSnapshot> {
    const runtime = BlockedListSettings.runtimeSnapshot()
    if (!ctx) {
      return runtime.ownerKey === ownerKey ? runtime : BlockedListSettings.empty(ownerKey)
    }
    const cached = await BlockedListSettings.loadSnapshotForOwner(ctx, ownerKey)
    if (runtime.ownerKey === ownerKey && runtime.updatedAt >= cached.updatedAt) {
      return runtime
    }
    return cached
  }

  private static nextDeltaSnapshot(
    base: BlockedListSnapshot,
    deltaType: string,
    targetId: number,
    deltaValue: boolean,
    ownerKey: string,
  ): BlockedListSnapshot {
    const ignoredTopicIds = BlockedListSettings.normalizeIds(base.ignoredTopicIds)
    const blockedMemberIds = BlockedListSettings.normalizeIds(base.blockedMemberIds)
    if (deltaType === 'ignored_topic') {
      return {
        ignoredTopicIds: BlockedListSettings.nextIds(ignoredTopicIds, targetId, deltaValue),
        blockedMemberIds: blockedMemberIds,
        blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(base.blockedMemberMetas, blockedMemberIds),
        ownerKey: ownerKey,
        updatedAt: Date.now(),
      }
    }
    return {
      ignoredTopicIds: ignoredTopicIds,
      blockedMemberIds: BlockedListSettings.nextIds(blockedMemberIds, targetId, deltaValue),
      blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(base.blockedMemberMetas, BlockedListSettings.nextIds(blockedMemberIds, targetId, deltaValue)),
      ownerKey: ownerKey,
      updatedAt: Date.now(),
    }
  }

  private static nextIds(values: number[], targetId: number, shouldInclude: boolean): number[] {
    const normalized = BlockedListSettings.normalizeIds(values)
    const exists = normalized.indexOf(targetId) >= 0
    if (shouldInclude) {
      return exists ? normalized : normalized.concat([targetId])
    }
    if (!exists) {
      return normalized
    }
    return normalized.filter((value: number) => value !== targetId)
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
      blocked_member_meta_count: snapshot.blockedMemberMetas.length,
      updatedAt: snapshot.updatedAt || 0,
    }
  }

  private static cacheLogContext(snapshot: BlockedListSnapshot, cacheHit: boolean): BlockedListCacheLogContext {
    return {
      ownerKeyPresent: !!snapshot.ownerKey,
      ownerKeyHash: snapshot.ownerKey ? DiagnosticLogger.ownerHash(snapshot.ownerKey) : '',
      ignored_count: snapshot.ignoredTopicIds.length,
      blocked_count: snapshot.blockedMemberIds.length,
      blocked_member_meta_count: snapshot.blockedMemberMetas.length,
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
      blocked_member_meta_count: snapshotContext.blocked_member_meta_count,
      updatedAt: snapshotContext.updatedAt,
    }
  }

  private static deltaOwnerLogContext(
    source: BlockedListCaptureSource,
    ownerKey: string,
    deltaType: string,
    targetId: number,
    deltaValue: boolean,
  ): BlockedListDeltaOwnerLogContext {
    const sourceContext = BlockedListSettings.sourceOwnerLogContext(source, ownerKey)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      ownerKeyPresent: sourceContext.ownerKeyPresent,
      ownerKeyHash: sourceContext.ownerKeyHash,
      deltaType: deltaType,
      targetId: targetId,
      deltaValue: deltaValue,
    }
  }

  private static deltaSnapshotLogContext(
    source: BlockedListCaptureSource,
    snapshot: BlockedListSnapshot,
    deltaType: string,
    targetId: number,
    deltaValue: boolean,
  ): BlockedListDeltaLogContext {
    const sourceContext = BlockedListSettings.sourceSnapshotLogContext(source, snapshot)
    return {
      endpoint: sourceContext.endpoint,
      source: sourceContext.source,
      trigger: sourceContext.trigger,
      statusCode: sourceContext.statusCode,
      locationType: sourceContext.locationType,
      bodyLength: sourceContext.bodyLength,
      hasCookie: sourceContext.hasCookie,
      hasUsername: sourceContext.hasUsername,
      ownerKeyPresent: sourceContext.ownerKeyPresent,
      ownerKeyHash: sourceContext.ownerKeyHash,
      ignored_count: sourceContext.ignored_count,
      blocked_count: sourceContext.blocked_count,
      blocked_member_meta_count: sourceContext.blocked_member_meta_count,
      updatedAt: sourceContext.updatedAt,
      deltaType: deltaType,
      targetId: targetId,
      deltaValue: deltaValue,
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
    const blockedMemberIds = BlockedListSettings.normalizeIds(value.blockedMemberIds || [])
    return {
      ignoredTopicIds: BlockedListSettings.normalizeIds(value.ignoredTopicIds || []),
      blockedMemberIds: blockedMemberIds,
      blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(value.blockedMemberMetas || [], blockedMemberIds),
      ownerKey: ownerKey,
      updatedAt: Number.isFinite(value.updatedAt) ? (value.updatedAt || 0) : 0,
    }
  }

  private static normalizeMemberMetas(values: BlockedMemberMeta[], blockedMemberIds: number[]): BlockedMemberMeta[] {
    const allowedIds: Set<number> = new Set(blockedMemberIds)
    const byId: Map<number, BlockedMemberMeta> = new Map()
    const source = Array.isArray(values) ? values : []
    for (const value of source) {
      const meta = BlockedListSettings.normalizeMemberMeta(value)
      if (meta.id > 0 && allowedIds.has(meta.id) && BlockedListSettings.hasVisibleMemberMeta(meta)) {
        byId.set(meta.id, meta)
      }
    }
    const result: BlockedMemberMeta[] = []
    for (const id of blockedMemberIds) {
      const meta = byId.get(id)
      if (meta) {
        result.push(meta)
      }
    }
    return result
  }

  private static normalizeMemberMeta(value: BlockedMemberMeta): BlockedMemberMeta {
    const updatedAt = Number.isFinite(value.updatedAt) ? value.updatedAt : Date.now()
    const created = Number.isFinite(value.created) ? value.created : 0
    return {
      id: Math.floor(value.id || 0),
      username: (value.username || '').trim(),
      tagline: (value.tagline || '').trim(),
      avatar: (value.avatar || '').trim(),
      created: created || 0,
      updatedAt: updatedAt || Date.now(),
    }
  }

  private static hasVisibleMemberMeta(meta: BlockedMemberMeta): boolean {
    return meta.username.length > 0 || meta.avatar.length > 0 || meta.tagline.length > 0 || meta.created > 0
  }

  private static upsertMemberMeta(values: BlockedMemberMeta[], meta: BlockedMemberMeta): BlockedMemberMeta[] {
    const byId: Map<number, BlockedMemberMeta> = new Map()
    const source = Array.isArray(values) ? values : []
    for (const value of source) {
      const normalized = BlockedListSettings.normalizeMemberMeta(value)
      if (normalized.id > 0 && BlockedListSettings.hasVisibleMemberMeta(normalized)) {
        byId.set(normalized.id, normalized)
      }
    }
    byId.set(meta.id, meta)
    return Array.from(byId.values())
  }

  private static memberMetaLogContext(ownerKey: string, meta: BlockedMemberMeta, metaCount: number): BlockedMemberMetaLogContext {
    const normalized = BlockedListSettings.normalizeMemberMeta(meta)
    return {
      ownerKeyPresent: !!ownerKey,
      ownerKeyHash: ownerKey ? DiagnosticLogger.ownerHash(ownerKey) : '',
      memberId: normalized.id,
      blocked_member_meta_count: metaCount,
      usernamePresent: normalized.username.length > 0,
      avatarPresent: normalized.avatar.length > 0,
      taglinePresent: normalized.tagline.length > 0,
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

  private static parseRuntimeMemberMetas(): BlockedMemberMeta[] {
    try {
      const values = JSON.parse(AppStorage.get<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS) || '[]') as BlockedMemberMeta[]
      return Array.isArray(values) ? values : []
    } catch (_error) {
      return []
    }
  }
}
