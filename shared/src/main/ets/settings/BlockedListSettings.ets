import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { HttpClient } from '../network/HttpClient'
import { StorageKeys } from '../constants/StorageKeys'
import { V2exTabParser, type V2exBlockedIdLists } from '../parser/V2exTabParser'
import { AccountStore } from './AccountStore'
import { STORE_NAME_SETTINGS, setAppStorageValue } from './SettingsStorage'
import { connectBlockedListStorage } from '../state/BlockedListState'
import { connectAuthSessionSignal } from '../state/AuthSessionSignalState'

const KEY_PREFIX: string = 'blockedListState:'

export interface BlockedMemberMeta {
  id: number
  username: string
  tagline: string
  avatar: string
  created: number
  updatedAt: number
}

export interface IgnoredTopicMeta {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  avatar: string
  memberPro: number
  created: number
  replies: number
  updatedAt: number
}

export interface BlockedListSnapshot {
  ignoredTopicIds: number[]
  blockedMemberIds: number[]
  blockedMemberMetas: BlockedMemberMeta[]
  ignoredTopicMetas: IgnoredTopicMeta[]
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
  ignored_topic_meta_count: number
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

interface IgnoredTopicMetaBatchLogContext extends BlockedListOwnerLogContext {
  requested_count: number
  applied_count: number
  ignored_topic_meta_count: number
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
    return { ignoredTopicIds: [], blockedMemberIds: [], blockedMemberMetas: [], ignoredTopicMetas: [], ownerKey: ownerKey, updatedAt: 0 }
  }

  static runtimeSnapshot(): BlockedListSnapshot {
    // Read the runtime ledger from the V2 BlockedListStorageState mirror that apply()/the meta upsert
    // writers keep in lockstep with the persisted AppStorage projections, instead of direct
    // AppStorage.get reads. ownerKey scoping is unchanged: empty / not-the-active-owner returns empty.
    const storage = connectBlockedListStorage()
    const ownerKey = storage.ownerKey || ''
    if (!ownerKey || ownerKey !== BlockedListSettings.activeOwnerKey()) {
      return BlockedListSettings.empty(BlockedListSettings.activeOwnerKey())
    }
    return BlockedListSettings.normalize({
      ignoredTopicIds: BlockedListSettings.parseRuntimeIds(storage.ignoredTopicIdsJson),
      blockedMemberIds: BlockedListSettings.parseRuntimeIds(storage.blockedMemberIdsJson),
      blockedMemberMetas: BlockedListSettings.parseRuntimeMemberMetas(),
      ignoredTopicMetas: BlockedListSettings.parseRuntimeIgnoredTopicMetas(),
      ownerKey: ownerKey,
      updatedAt: storage.updatedAt || 0,
    }, ownerKey)
  }

  static activeOwnerKey(): string {
    // Active-account id (precedence) then auth-session username (fallback) now come from the V2
    // holders that AccountStore.applyActiveAccountId / AuthSessionSettings.apply keep in lockstep,
    // instead of direct AppStorage.get reads. AccountStore.getActiveId() is the transient authority the
    // legacy ACTIVE_ACCOUNT_ID key only mirrored; identity precedence and owner-key shape are unchanged.
    const activeId = (AccountStore.getActiveId() || '').trim()
    const username = (connectAuthSessionSignal().username || '').trim()
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
    const runtimeTopicMetas = runtime.ownerKey === ownerKey ? runtime.ignoredTopicMetas : []
    const immediate = BlockedListSettings.normalize({
      ignoredTopicIds: snapshot.ignoredTopicIds,
      blockedMemberIds: snapshot.blockedMemberIds,
      blockedMemberMetas: runtimeMetas,
      ignoredTopicMetas: runtimeTopicMetas,
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
      ignoredTopicMetas: cached.ignoredTopicMetas.concat(immediate.ignoredTopicMetas),
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
    // V2EX web bug: the topic-list page can render the `ignored_topics` JS var as PRESENT but
    // EMPTY even when the account still has ignored topics. Trusting that empty value wipes the
    // local ignore cache, after which the user can no longer (un)ignore-manage from the app and
    // the settings count drops to 0. When the feed reports zero ignored topics but the cache holds
    // some, keep the cached set — the authoritative ways to clear an ignore are the in-app unignore
    // / reset flows, not a feed scrape. The blocked-members list is unaffected by this bug and
    // still syncs normally, so only the ignored side is preserved here.
    if (lists.ignoredTopicIds.length === 0) {
      const runtime = BlockedListSettings.runtimeSnapshot()
      if (runtime.ignoredTopicIds.length > 0) {
        lists.ignoredTopicIds = runtime.ignoredTopicIds
        DiagnosticLogger.info('storage', 'blocked_list_preserve_ignored_on_empty_feed', sourceContext)
      }
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
      ignoredTopicMetas: base.ignoredTopicMetas,
      ownerKey: ownerKey,
      updatedAt: base.updatedAt,
    }, ownerKey)
    if (BlockedListSettings.activeOwnerKey() === ownerKey) {
      // Active-owner runtime write: mirror only the member-metas field (ids/ownerKey/updatedAt stay
      // as-is) into both the AppStorage projection and the V2 holder runtimeSnapshot now reads.
      const blockedMemberMetasJson = JSON.stringify(normalized.blockedMemberMetas)
      setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS, blockedMemberMetasJson)
      connectBlockedListStorage().blockedMemberMetasJson = blockedMemberMetasJson
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
    const ignoredTopicIdsJson = JSON.stringify(snapshot.ignoredTopicIds)
    const blockedMemberIdsJson = JSON.stringify(snapshot.blockedMemberIds)
    const blockedMemberMetasJson = JSON.stringify(snapshot.blockedMemberMetas)
    const ignoredTopicMetasJson = JSON.stringify(snapshot.ignoredTopicMetas)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY, snapshot.ownerKey)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS, ignoredTopicIdsJson)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS, blockedMemberIdsJson)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_METAS, blockedMemberMetasJson)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_METAS, ignoredTopicMetasJson)
    setAppStorageValue<number>(StorageKeys.BLOCKED_LIST_UPDATED_AT, snapshot.updatedAt)
    // Dual-write the V2 mirror that BlockedListsPage observes (@Monitor) AND the imperative readers
    // (ApiService.applyActiveBlockedTopicFilter / runtimeSnapshot) now read, keeping it in lockstep with
    // the V1 AppStorage projections above. Single dual-write point, mirroring LocalDataPublisher ->
    // TopicReadStatesState. Owner key + member/topic metas are mirrored too so every imperative reader
    // can leave AppStorage.
    const storage = connectBlockedListStorage()
    storage.ownerKey = snapshot.ownerKey
    storage.ignoredTopicIdsJson = ignoredTopicIdsJson
    storage.blockedMemberIdsJson = blockedMemberIdsJson
    storage.blockedMemberMetasJson = blockedMemberMetasJson
    storage.ignoredTopicMetasJson = ignoredTopicMetasJson
    storage.updatedAt = snapshot.updatedAt
  }

  static async upsertIgnoredTopicMetas(metas: IgnoredTopicMeta[], context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      DiagnosticLogger.info('storage', 'ignored_topic_meta_skip_no_owner', BlockedListSettings.topicMetaBatchLogContext(ownerKey, 0, 0, 0))
      return
    }
    const normalizedMetas = (Array.isArray(metas) ? metas : [])
      .map((meta: IgnoredTopicMeta): IgnoredTopicMeta => BlockedListSettings.normalizeIgnoredTopicMeta(meta))
      .filter((meta: IgnoredTopicMeta): boolean => meta.id > 0 && BlockedListSettings.hasVisibleIgnoredTopicMeta(meta))
    if (normalizedMetas.length === 0) {
      DiagnosticLogger.info('storage', 'ignored_topic_meta_skip_empty', BlockedListSettings.topicMetaBatchLogContext(ownerKey, 0, 0, 0))
      return
    }
    return BlockedListSettings.enqueueSnapshotWrite(() => BlockedListSettings.upsertIgnoredTopicMetasLocked(ownerKey, normalizedMetas, context, source))
  }

  private static async upsertIgnoredTopicMetasLocked(ownerKey: string, normalizedMetas: IgnoredTopicMeta[], context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void> {
    const ctx = context || BlockedListSettings.context
    const base = await BlockedListSettings.snapshotForOwnerWrite(ctx, ownerKey)
    const allowedIds: Set<number> = new Set(base.ignoredTopicIds)
    const applicable = normalizedMetas.filter((meta: IgnoredTopicMeta): boolean => allowedIds.has(meta.id))
    if (applicable.length === 0) {
      DiagnosticLogger.info('storage', 'ignored_topic_meta_skip_not_ignored', BlockedListSettings.topicMetaBatchLogContext(ownerKey, normalizedMetas.length, 0, base.ignoredTopicMetas.length))
      return
    }
    let mergedMetas = base.ignoredTopicMetas
    for (const meta of applicable) {
      mergedMetas = BlockedListSettings.mergeIgnoredTopicMeta(mergedMetas, meta)
    }
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: base.ignoredTopicIds,
      blockedMemberIds: base.blockedMemberIds,
      blockedMemberMetas: base.blockedMemberMetas,
      ignoredTopicMetas: mergedMetas,
      ownerKey: ownerKey,
      updatedAt: base.updatedAt,
    }, ownerKey)
    if (BlockedListSettings.activeOwnerKey() === ownerKey) {
      // Active-owner runtime write: mirror only the ignored-topic-metas field (ids/ownerKey/updatedAt
      // stay as-is) into both the AppStorage projection and the V2 holder runtimeSnapshot now reads.
      const ignoredTopicMetasJson = JSON.stringify(normalized.ignoredTopicMetas)
      setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_METAS, ignoredTopicMetasJson)
      connectBlockedListStorage().ignoredTopicMetasJson = ignoredTopicMetasJson
    }
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'ignored_topic_meta_no_context_runtime_only', BlockedListSettings.topicMetaBatchLogContext(ownerKey, normalizedMetas.length, applicable.length, normalized.ignoredTopicMetas.length))
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))
      store.flushSync()
      DiagnosticLogger.info('storage', 'ignored_topic_meta_upsert_success', BlockedListSettings.topicMetaBatchLogContext(ownerKey, normalizedMetas.length, applicable.length, normalized.ignoredTopicMetas.length))
    } catch (error) {
      DiagnosticLogger.exception('storage', 'ignored_topic_meta_upsert_exception', error as Error, BlockedListSettings.topicMetaBatchLogContext(ownerKey, normalizedMetas.length, applicable.length, normalized.ignoredTopicMetas.length))
    }
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
      ignoredTopicMetas: cached.ignoredTopicMetas.concat(immediate.ignoredTopicMetas),
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
        ignoredTopicMetas: BlockedListSettings.normalizeIgnoredTopicMetas(base.ignoredTopicMetas, BlockedListSettings.nextIds(ignoredTopicIds, targetId, deltaValue)),
        ownerKey: ownerKey,
        updatedAt: Date.now(),
      }
    }
    return {
      ignoredTopicIds: ignoredTopicIds,
      blockedMemberIds: BlockedListSettings.nextIds(blockedMemberIds, targetId, deltaValue),
      blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(base.blockedMemberMetas, BlockedListSettings.nextIds(blockedMemberIds, targetId, deltaValue)),
      ignoredTopicMetas: BlockedListSettings.normalizeIgnoredTopicMetas(base.ignoredTopicMetas, ignoredTopicIds),
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
      ignored_topic_meta_count: snapshot.ignoredTopicMetas.length,
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
      ignored_topic_meta_count: snapshot.ignoredTopicMetas.length,
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
      ignored_topic_meta_count: snapshotContext.ignored_topic_meta_count,
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
      ignored_topic_meta_count: sourceContext.ignored_topic_meta_count,
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
    const ignoredTopicIds = BlockedListSettings.normalizeIds(value.ignoredTopicIds || [])
    const blockedMemberIds = BlockedListSettings.normalizeIds(value.blockedMemberIds || [])
    return {
      ignoredTopicIds: ignoredTopicIds,
      blockedMemberIds: blockedMemberIds,
      blockedMemberMetas: BlockedListSettings.normalizeMemberMetas(value.blockedMemberMetas || [], blockedMemberIds),
      ignoredTopicMetas: BlockedListSettings.normalizeIgnoredTopicMetas(value.ignoredTopicMetas || [], ignoredTopicIds),
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

  private static normalizeIgnoredTopicMetas(values: IgnoredTopicMeta[], ignoredTopicIds: number[]): IgnoredTopicMeta[] {
    const allowedIds: Set<number> = new Set(ignoredTopicIds)
    const byId: Map<number, IgnoredTopicMeta> = new Map()
    const source = Array.isArray(values) ? values : []
    for (const value of source) {
      const meta = BlockedListSettings.normalizeIgnoredTopicMeta(value)
      if (meta.id > 0 && allowedIds.has(meta.id) && BlockedListSettings.hasVisibleIgnoredTopicMeta(meta)) {
        byId.set(meta.id, meta)
      }
    }
    const result: IgnoredTopicMeta[] = []
    for (const id of ignoredTopicIds) {
      const meta = byId.get(id)
      if (meta) {
        result.push(meta)
      }
    }
    return result
  }

  private static normalizeIgnoredTopicMeta(value: IgnoredTopicMeta): IgnoredTopicMeta {
    const updatedAt = Number.isFinite(value.updatedAt) ? value.updatedAt : Date.now()
    const created = Number.isFinite(value.created) ? value.created : 0
    const replies = Number.isFinite(value.replies) ? value.replies : 0
    const memberPro = Number.isFinite(value.memberPro) ? value.memberPro : 0
    return {
      id: Math.floor(value.id || 0),
      title: (value.title || '').trim(),
      nodeName: (value.nodeName || '').trim(),
      nodeTitle: (value.nodeTitle || '').trim(),
      username: (value.username || '').trim(),
      avatar: (value.avatar || '').trim(),
      memberPro: Math.floor(memberPro || 0),
      created: created || 0,
      replies: Math.floor(replies || 0),
      updatedAt: updatedAt || Date.now(),
    }
  }

  private static hasVisibleIgnoredTopicMeta(meta: IgnoredTopicMeta): boolean {
    return meta.title.length > 0 || meta.username.length > 0 || meta.nodeName.length > 0 || meta.nodeTitle.length > 0 || meta.avatar.length > 0
  }

  private static mergeIgnoredTopicMeta(values: IgnoredTopicMeta[], meta: IgnoredTopicMeta): IgnoredTopicMeta[] {
    const byId: Map<number, IgnoredTopicMeta> = new Map()
    const source = Array.isArray(values) ? values : []
    for (const value of source) {
      const normalized = BlockedListSettings.normalizeIgnoredTopicMeta(value)
      if (normalized.id > 0 && BlockedListSettings.hasVisibleIgnoredTopicMeta(normalized)) {
        byId.set(normalized.id, normalized)
      }
    }
    byId.set(meta.id, meta)
    return Array.from(byId.values())
  }

  private static topicMetaBatchLogContext(ownerKey: string, requestedCount: number, appliedCount: number, metaCount: number): IgnoredTopicMetaBatchLogContext {
    return {
      ownerKeyPresent: !!ownerKey,
      ownerKeyHash: ownerKey ? DiagnosticLogger.ownerHash(ownerKey) : '',
      requested_count: requestedCount,
      applied_count: appliedCount,
      ignored_topic_meta_count: metaCount,
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

  private static parseRuntimeIds(json: string): number[] {
    try {
      const values = JSON.parse(json || '[]') as number[]
      return Array.isArray(values) ? values : []
    } catch (_error) {
      return []
    }
  }

  private static parseRuntimeMemberMetas(): BlockedMemberMeta[] {
    try {
      const values = JSON.parse(connectBlockedListStorage().blockedMemberMetasJson || '[]') as BlockedMemberMeta[]
      return Array.isArray(values) ? values : []
    } catch (_error) {
      return []
    }
  }

  private static parseRuntimeIgnoredTopicMetas(): IgnoredTopicMeta[] {
    try {
      const values = JSON.parse(connectBlockedListStorage().ignoredTopicMetasJson || '[]') as IgnoredTopicMeta[]
      return Array.isArray(values) ? values : []
    } catch (_error) {
      return []
    }
  }
}
