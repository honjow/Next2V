import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from '../storage/LocalDataStore'
import type { CacheScope } from './CacheOwnerResolver'

export interface TopicDetailActionOverlay {
  ownerKey: string
  baseUrl: string
  accountId: string
  loginMode: string
  topicId: number
  favoriteKnown: boolean
  favoriteValue: boolean
  topicThankKnown: boolean
  topicThankValue: boolean
  replyThankedIds: number[]
  replyThankCounts: Record<string, number>
  source: string
  updatedAt: number
  expiresAt: number
}

const SQL_SELECT_TOPIC_OVERLAY: string = 'SELECT owner_key, base_url, account_id, login_mode, topic_id, favorite_known, favorite_value, topic_thank_known, topic_thank_value, reply_thanked_ids_json, reply_thank_counts_json, source, updated_at, expires_at FROM topic_action_overlays WHERE owner_key = ? AND topic_id = ? AND expires_at > ? LIMIT 1'
const SQL_UPSERT_TOPIC_OVERLAY: string = 'INSERT OR REPLACE INTO topic_action_overlays (owner_key, base_url, account_id, login_mode, topic_id, favorite_known, favorite_value, topic_thank_known, topic_thank_value, reply_thanked_ids_json, reply_thank_counts_json, source, updated_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
const SQL_DELETE_OWNER: string = 'DELETE FROM topic_action_overlays WHERE base_url = ? AND account_id = ?'
const SQL_CLEAR_ALL: string = 'DELETE FROM topic_action_overlays'
const SQL_PRUNE_EXPIRED: string = 'DELETE FROM topic_action_overlays WHERE expires_at <= ?'
const OVERLAY_TTL_SECONDS: number = 90 * 24 * 60 * 60

export class TopicDetailActionOverlaySettings {
  static async loadTopicOverlay(context: common.UIAbilityContext, scope: CacheScope | null, topicId: number): Promise<TopicDetailActionOverlay | null> {
    if (!scope || scope.ownerType !== 'account' || topicId <= 0) {
      return null
    }
    const store = await LocalDataStore.open(context)
    const now = TopicDetailActionOverlaySettings.nowSeconds()
    const resultSet = await store.querySql(SQL_SELECT_TOPIC_OVERLAY, [scope.ownerKey, topicId, now])
    try {
      if (!resultSet.goToNextRow()) {
        return null
      }
      return TopicDetailActionOverlaySettings.readOverlay(resultSet)
    } finally {
      resultSet.close()
      TopicDetailActionOverlaySettings.pruneExpired(context).catch((_error: Error) => {})
    }
  }

  static async commitTopicFavorite(context: common.UIAbilityContext, scope: CacheScope | null, topicId: number, value: boolean): Promise<void> {
    const overlay = await TopicDetailActionOverlaySettings.loadOrCreateOverlay(context, scope, topicId, 'favorite')
    if (!overlay) {
      return
    }
    overlay.favoriteKnown = true
    overlay.favoriteValue = value
    await TopicDetailActionOverlaySettings.saveOverlay(context, overlay)
  }

  static async commitTopicThank(context: common.UIAbilityContext, scope: CacheScope | null, topicId: number): Promise<void> {
    const overlay = await TopicDetailActionOverlaySettings.loadOrCreateOverlay(context, scope, topicId, 'topicThank')
    if (!overlay) {
      return
    }
    // Topic thank is one-way on V2EX, so a confirmed success/already-thanked response stays durable until
    // a same-owner authenticated contradiction is added in a future parser path.
    overlay.topicThankKnown = true
    overlay.topicThankValue = true
    await TopicDetailActionOverlaySettings.saveOverlay(context, overlay)
  }

  static async commitReplyThank(context: common.UIAbilityContext, scope: CacheScope | null, topicId: number, replyId: number, countAfterSuccess?: number): Promise<void> {
    if (replyId <= 0) {
      return
    }
    const overlay = await TopicDetailActionOverlaySettings.loadOrCreateOverlay(context, scope, topicId, 'replyThank')
    if (!overlay) {
      return
    }
    if (!overlay.replyThankedIds.includes(replyId)) {
      overlay.replyThankedIds.push(replyId)
    }
    if (countAfterSuccess !== undefined && countAfterSuccess > 0) {
      overlay.replyThankCounts[replyId.toString()] = countAfterSuccess
    }
    await TopicDetailActionOverlaySettings.saveOverlay(context, overlay)
  }

  static async clearByOwner(context: common.UIAbilityContext, baseUrl: string, accountId: string): Promise<void> {
    if (!baseUrl || !accountId) {
      return
    }
    const store = await LocalDataStore.open(context)
    // Clearing exact owner on account removal avoids keeping private/action state that could later match a
    // recycled account id after domain/account switching code changes.
    await store.executeSql(SQL_DELETE_OWNER, [baseUrl, accountId])
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    const store = await LocalDataStore.open(context)
    await store.executeSql(SQL_CLEAR_ALL)
  }

  static async pruneExpired(context: common.UIAbilityContext): Promise<void> {
    const store = await LocalDataStore.open(context)
    await store.executeSql(SQL_PRUNE_EXPIRED, [TopicDetailActionOverlaySettings.nowSeconds()])
  }

  private static async loadOrCreateOverlay(context: common.UIAbilityContext, scope: CacheScope | null, topicId: number, source: string): Promise<TopicDetailActionOverlay | null> {
    if (!scope || scope.ownerType !== 'account' || topicId <= 0) {
      return null
    }
    const existing = await TopicDetailActionOverlaySettings.loadTopicOverlay(context, scope, topicId)
    if (existing) {
      existing.source = source
      return existing
    }
    const now = TopicDetailActionOverlaySettings.nowSeconds()
    return {
      ownerKey: scope.ownerKey,
      baseUrl: scope.baseUrl,
      accountId: scope.accountId,
      loginMode: scope.loginMode,
      topicId,
      favoriteKnown: false,
      favoriteValue: false,
      topicThankKnown: false,
      topicThankValue: false,
      replyThankedIds: [],
      replyThankCounts: {},
      source,
      updatedAt: now,
      expiresAt: now + OVERLAY_TTL_SECONDS,
    }
  }

  private static async saveOverlay(context: common.UIAbilityContext, overlay: TopicDetailActionOverlay): Promise<void> {
    const now = TopicDetailActionOverlaySettings.nowSeconds()
    overlay.updatedAt = now
    overlay.expiresAt = now + OVERLAY_TTL_SECONDS
    const args: relationalStore.ValueType[] = [
      overlay.ownerKey,
      overlay.baseUrl,
      overlay.accountId,
      overlay.loginMode,
      overlay.topicId,
      overlay.favoriteKnown ? 1 : 0,
      overlay.favoriteValue ? 1 : 0,
      overlay.topicThankKnown ? 1 : 0,
      overlay.topicThankValue ? 1 : 0,
      JSON.stringify(overlay.replyThankedIds || []),
      JSON.stringify(overlay.replyThankCounts || {}),
      overlay.source,
      overlay.updatedAt,
      overlay.expiresAt,
    ]
    const store = await LocalDataStore.open(context)
    await store.executeSql(SQL_UPSERT_TOPIC_OVERLAY, args)
  }

  private static readOverlay(resultSet: relationalStore.ResultSet): TopicDetailActionOverlay {
    return {
      ownerKey: resultSet.getString(resultSet.getColumnIndex('owner_key')),
      baseUrl: resultSet.getString(resultSet.getColumnIndex('base_url')),
      accountId: resultSet.getString(resultSet.getColumnIndex('account_id')),
      loginMode: resultSet.getString(resultSet.getColumnIndex('login_mode')),
      topicId: resultSet.getLong(resultSet.getColumnIndex('topic_id')),
      favoriteKnown: resultSet.getLong(resultSet.getColumnIndex('favorite_known')) > 0,
      favoriteValue: resultSet.getLong(resultSet.getColumnIndex('favorite_value')) > 0,
      topicThankKnown: resultSet.getLong(resultSet.getColumnIndex('topic_thank_known')) > 0,
      topicThankValue: resultSet.getLong(resultSet.getColumnIndex('topic_thank_value')) > 0,
      replyThankedIds: TopicDetailActionOverlaySettings.parseNumberArray(resultSet.getString(resultSet.getColumnIndex('reply_thanked_ids_json'))),
      replyThankCounts: TopicDetailActionOverlaySettings.parseNumberRecord(resultSet.getString(resultSet.getColumnIndex('reply_thank_counts_json'))),
      source: resultSet.getString(resultSet.getColumnIndex('source')),
      updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at')),
      expiresAt: resultSet.getLong(resultSet.getColumnIndex('expires_at')),
    }
  }

  private static parseNumberArray(raw: string): number[] {
    try {
      const parsed = JSON.parse(raw || '[]') as number[]
      return Array.isArray(parsed) ? parsed.filter((item: number) => item > 0) : []
    } catch (_error) {
      return []
    }
  }

  private static parseNumberRecord(raw: string): Record<string, number> {
    try {
      const parsed = JSON.parse(raw || '{}') as Record<string, number>
      return parsed || {}
    } catch (_error) {
      return {}
    }
  }

  private static nowSeconds(): number {
    return Math.floor(Date.now() / 1000)
  }
}
