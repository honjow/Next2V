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

export class BlockedListSettings {
  private static context: common.UIAbilityContext | null = null

  static setContext(context: common.UIAbilityContext): void {
    BlockedListSettings.context = context
  }

  static empty(ownerKey: string = ''): BlockedListSnapshot {
    return { ignoredTopicIds: [], blockedMemberIds: [], ownerKey: ownerKey, updatedAt: 0 }
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
      return BlockedListSettings.empty('')
    }
    const ctx = context || BlockedListSettings.context
    if (!ctx) {
      return BlockedListSettings.empty(ownerKey)
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      const raw = store.getSync(KEY_PREFIX + ownerKey, '') as string
      if (!raw) {
        return BlockedListSettings.empty(ownerKey)
      }
      const parsed = JSON.parse(raw) as BlockedListSnapshot
      return BlockedListSettings.normalize(parsed, ownerKey)
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_list_load_exception', error as Error, { ownerKey: ownerKey })
      return BlockedListSettings.empty(ownerKey)
    }
  }

  static async saveActive(snapshot: V2exBlockedIdLists, context?: common.UIAbilityContext): Promise<void> {
    const ownerKey = BlockedListSettings.activeOwnerKey()
    if (!ownerKey) {
      DiagnosticLogger.info('storage', 'blocked_list_skip_save_no_owner', {})
      return
    }
    const normalized = BlockedListSettings.normalize({
      ignoredTopicIds: snapshot.ignoredTopicIds,
      blockedMemberIds: snapshot.blockedMemberIds,
      ownerKey: ownerKey,
      updatedAt: Date.now(),
    }, ownerKey)
    BlockedListSettings.apply(normalized)
    const ctx = context || BlockedListSettings.context
    if (!ctx) {
      DiagnosticLogger.warn('storage', 'blocked_list_no_context_runtime_only', { ownerKey: ownerKey })
      return
    }
    try {
      const store = await preferences.getPreferences(ctx, STORE_NAME_SETTINGS)
      store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.exception('storage', 'blocked_list_save_exception', error as Error, { ownerKey: ownerKey })
    }
  }

  static updateFromTopicListHtml(html: string): void {
    const lists = V2exTabParser.extractBlockedIdLists(html || '')
    if (lists.ignoredTopicIds.length === 0 && lists.blockedMemberIds.length === 0) {
      DiagnosticLogger.info('network', 'blocked_list_extract_empty_or_missing', {})
      return
    }
    DiagnosticLogger.info('network', 'blocked_list_extract_success', {
      ignoredTopics: lists.ignoredTopicIds.length,
      blockedMembers: lists.blockedMemberIds.length,
    })
    BlockedListSettings.saveActive(lists).catch((error: Error) => {
      DiagnosticLogger.exception('storage', 'blocked_list_save_from_html_exception', error, {})
    })
  }

  static apply(snapshot: BlockedListSnapshot): void {
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_OWNER_KEY, snapshot.ownerKey)
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS, JSON.stringify(snapshot.ignoredTopicIds))
    setAppStorageValue<string>(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS, JSON.stringify(snapshot.blockedMemberIds))
    setAppStorageValue<number>(StorageKeys.BLOCKED_LIST_UPDATED_AT, snapshot.updatedAt)
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
}
