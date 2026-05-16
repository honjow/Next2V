import { common } from '@kit.AbilityKit'
import { StorageKeys } from '../constants/StorageKeys'
import { BlockedTopicFilter } from '../utils/BlockedTopicFilter'
import { readJsonArray, setAppStorageValue, withPreferencesStore, writeJsonValue } from './SettingsStorage'
import { STORE_NAME_BLOCKED_MEMBERS } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_BLOCKED_MEMBERS
const KEY_USERNAMES: string = 'usernames'
const KEY_UPDATED_AT: string = 'updatedAt'

export interface BlockedMemberSnapshot {
  usernames: string[]
  updatedAt: number
}

export class BlockedMemberSettings {
  private static cachedUsernames: string[] = []

  static async load(context: common.UIAbilityContext): Promise<BlockedMemberSnapshot> {
    try {
      return await withPreferencesStore<BlockedMemberSnapshot>(context, STORE_NAME, (store) => {
        const parsed = readJsonArray<string>(store, KEY_USERNAMES, [])
        const updatedAt = store.getSync(KEY_UPDATED_AT, 0) as number
        const usernames = BlockedMemberSettings.normalizeList(parsed)
        BlockedMemberSettings.cachedUsernames = usernames
        return {
          usernames: usernames,
          updatedAt: updatedAt || 0
        }
      })
    } catch (_error) {
      return { usernames: [], updatedAt: 0 }
    }
  }

  static async loadUsernames(context: common.UIAbilityContext): Promise<string[]> {
    const snapshot = await BlockedMemberSettings.load(context)
    return snapshot.usernames
  }

  static async saveUsernames(context: common.UIAbilityContext, usernames: string[]): Promise<void> {
    const normalized = BlockedMemberSettings.normalizeList(usernames)
    const updatedAt = Date.now()
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        writeJsonValue<string[]>(store, KEY_USERNAMES, normalized, false)
        store.putSync(KEY_UPDATED_AT, updatedAt)
        store.flushSync()
      })
      BlockedMemberSettings.cachedUsernames = normalized
      BlockedMemberSettings.publishUpdatedAt(updatedAt)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存屏蔽用户缓存失败')
    }
  }

  static async setBlocked(context: common.UIAbilityContext, username: string, blocked: boolean): Promise<void> {
    const normalized = BlockedTopicFilter.normalizeUsername(username)
    if (!normalized) {
      return
    }
    const current = await BlockedMemberSettings.loadUsernames(context)
    const nextSet: Set<string> = new Set(BlockedMemberSettings.normalizeList(current))
    if (blocked) {
      nextSet.add(normalized)
    } else {
      nextSet.delete(normalized)
    }
    await BlockedMemberSettings.saveUsernames(context, Array.from(nextSet))
  }

  static publishUpdatedAt(updatedAt: number = Date.now()): void {
    setAppStorageValue<number>(StorageKeys.BLOCKED_MEMBERS_UPDATED_AT, updatedAt)
  }

  static getCachedUsernames(): string[] {
    return BlockedMemberSettings.cachedUsernames.slice()
  }

  static applyRuntimeUsernames(usernames: string[]): void {
    BlockedMemberSettings.cachedUsernames = BlockedMemberSettings.normalizeList(usernames)
  }

  private static normalizeList(usernames: string[]): string[] {
    const seen: Set<string> = new Set()
    for (const username of usernames || []) {
      const normalized = BlockedTopicFilter.normalizeUsername(username)
      if (normalized) {
        seen.add(normalized)
      }
    }
    return Array.from(seen).sort()
  }
}
