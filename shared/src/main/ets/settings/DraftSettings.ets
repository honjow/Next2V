import { common } from '@kit.AbilityKit'
import { deleteKeysAndFlush, readJsonArray, readJsonObject, withPreferencesStore, writeJsonValue } from './SettingsStorage'
import { connectLocalDataSignal } from '../state/LocalDataSignalState'
import { STORE_NAME_DRAFTS } from './SettingsStores'
import { AppStrings } from '../i18n/AppStrings'

const STORE_NAME: string = STORE_NAME_DRAFTS
const KEY_REPLY_DRAFTS: string = 'replyDrafts'
const KEY_TOPIC_DRAFT: string = 'topicDraft'
// Per-topic, per-mode drafts for 附言(append) + 编辑(edit) — keyed by `${mode}:${topicId}` so an append
// draft and an edit draft for the same topic never collide, and neither collides with the create draft.
const KEY_COMPOSE_DRAFTS: string = 'composeDrafts'
const MAX_REPLY_DRAFTS: number = 50
const MAX_COMPOSE_DRAFTS: number = 30

export interface ReplyDraft {
  topicId: number
  content: string
  updatedAt: number
}

export interface ComposeDraft {
  // Identity = `${mode}:${topicId}` (e.g. "append:123", "edit:123").
  key: string
  mode: string
  topicId: number
  // Append has no title; edit carries the in-progress title. Empty for append.
  title: string
  content: string
  updatedAt: number
}

export interface TopicDraft {
  nodeName: string
  // Display title of the chosen node (e.g. "沙盒" for nodeName "sandbox"). Persisted so reopening the
  // draft can show the node bilingually instead of only its English name. Optional for older drafts.
  nodeTitle?: string
  title: string
  content: string
  updatedAt: number
}

export class DraftSettings {
  static async loadTopicDraft(context: common.UIAbilityContext): Promise<TopicDraft | null> {
    try {
      return await withPreferencesStore<TopicDraft | null>(context, STORE_NAME, (store) => {
        const parsed = readJsonObject<TopicDraft>(store, KEY_TOPIC_DRAFT, null)
        return DraftSettings.parseTopicDraft(parsed)
      })
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read draft')
    }
  }

  // Returns the unix-seconds timestamp persisted on the draft (0 when the draft
  // was empty and therefore cleared). Callers that need to display the saved time
  // should use this return value rather than recomputing the clock, so the shown
  // time always matches what was written.
  static async saveTopicDraft(context: common.UIAbilityContext, nodeName: string, title: string, content: string, nodeTitle: string = ''): Promise<number> {
    const cleanNode = (nodeName ?? '').trim()
    const cleanTitle = (title ?? '').trim()
    const cleanContent = content ?? ''
    if (!cleanNode && !cleanTitle && cleanContent.trim().length === 0) {
      await DraftSettings.clearTopicDraft(context)
      return 0
    }
    const updatedAt = Math.floor(Date.now() / 1000)
    const draft: TopicDraft = {
      nodeName: cleanNode,
      nodeTitle: (nodeTitle ?? '').trim(),
      title: cleanTitle,
      content: cleanContent,
      updatedAt: updatedAt
    }
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        writeJsonValue<TopicDraft>(store, KEY_TOPIC_DRAFT, draft)
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save draft')
    }
    return updatedAt
  }

  static async clearTopicDraft(context: common.UIAbilityContext): Promise<void> {
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        deleteKeysAndFlush(store, [KEY_TOPIC_DRAFT])
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to clear draft')
    }
  }

  static composeKey(mode: string, topicId: number): string {
    return `${mode}:${topicId}`
  }

  static async loadComposeDraft(context: common.UIAbilityContext, mode: string, topicId: number): Promise<ComposeDraft | null> {
    if (topicId <= 0) {
      return null
    }
    const all = await DraftSettings.loadAllComposeDrafts(context)
    const key = DraftSettings.composeKey(mode, topicId)
    const match = all.find((item: ComposeDraft) => item.key === key)
    return match ? match : null
  }

  static async saveComposeDraft(context: common.UIAbilityContext, mode: string, topicId: number, title: string, content: string): Promise<number> {
    if (topicId <= 0) {
      return 0
    }
    const all = await DraftSettings.loadAllComposeDrafts(context)
    const key = DraftSettings.composeKey(mode, topicId)
    const cleanTitle = (title ?? '').trim()
    const cleanContent = content ?? ''
    if (cleanTitle.length === 0 && cleanContent.trim().length === 0) {
      await DraftSettings.writeAllComposeDrafts(context, all.filter((item: ComposeDraft) => item.key !== key))
      return 0
    }
    const updatedAt = Math.floor(Date.now() / 1000)
    const draft: ComposeDraft = { key: key, mode: mode, topicId: topicId, title: cleanTitle, content: cleanContent, updatedAt: updatedAt }
    const next = [draft].concat(all.filter((item: ComposeDraft) => item.key !== key)).slice(0, MAX_COMPOSE_DRAFTS)
    await DraftSettings.writeAllComposeDrafts(context, next)
    return updatedAt
  }

  static async clearComposeDraft(context: common.UIAbilityContext, mode: string, topicId: number): Promise<void> {
    if (topicId <= 0) {
      return
    }
    const all = await DraftSettings.loadAllComposeDrafts(context)
    const key = DraftSettings.composeKey(mode, topicId)
    await DraftSettings.writeAllComposeDrafts(context, all.filter((item: ComposeDraft) => item.key !== key))
  }

  static async loadReplyDraft(context: common.UIAbilityContext, topicId: number): Promise<ReplyDraft | null> {
    if (topicId <= 0) {
      return null
    }
    const drafts = await DraftSettings.loadAllReplyDrafts(context)
    const match = drafts.find((item: ReplyDraft) => item.topicId === topicId)
    return match ? match : null
  }

  static async saveReplyDraft(context: common.UIAbilityContext, topicId: number, content: string): Promise<void> {
    if (topicId <= 0) {
      return
    }
    const drafts = await DraftSettings.loadAllReplyDrafts(context)
    const clean = content ?? ''
    let next: ReplyDraft[]
    if (clean.trim().length === 0) {
      next = drafts.filter((item: ReplyDraft) => item.topicId !== topicId)
    } else {
      const updated: ReplyDraft = { topicId: topicId, content: clean, updatedAt: Math.floor(Date.now() / 1000) }
      next = [updated].concat(drafts.filter((item: ReplyDraft) => item.topicId !== topicId)).slice(0, MAX_REPLY_DRAFTS)
    }
    await DraftSettings.writeAllReplyDrafts(context, next)
  }

  static async clearReplyDraft(context: common.UIAbilityContext, topicId: number): Promise<void> {
    if (topicId <= 0) {
      return
    }
    const drafts = await DraftSettings.loadAllReplyDrafts(context)
    const next = drafts.filter((item: ReplyDraft) => item.topicId !== topicId)
    await DraftSettings.writeAllReplyDrafts(context, next)
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        deleteKeysAndFlush(store, [KEY_TOPIC_DRAFT, KEY_REPLY_DRAFTS, KEY_COMPOSE_DRAFTS])
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text($r('app.string.draft_clear_failed'), 'Failed to clear drafts'))
    }
  }

  static async exportReplyDraftsForBackup(context: common.UIAbilityContext): Promise<ReplyDraft[]> {
    return await DraftSettings.loadAllReplyDrafts(context)
  }

  static async restoreBackup(context: common.UIAbilityContext, replyDrafts: ReplyDraft[], topicDraft: TopicDraft | null): Promise<void> {
    const cleanReplies = DraftSettings.parseReplyDrafts(replyDrafts || [])
    const cleanTopic = DraftSettings.parseTopicDraft(topicDraft)
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        if (cleanTopic) {
          writeJsonValue<TopicDraft>(store, KEY_TOPIC_DRAFT, cleanTopic, false)
        } else {
          store.deleteSync(KEY_TOPIC_DRAFT)
        }
        writeJsonValue<ReplyDraft[]>(store, KEY_REPLY_DRAFTS, cleanReplies, false)
        store.flushSync()
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to restore drafts')
    }
  }

  private static async loadAllReplyDrafts(context: common.UIAbilityContext): Promise<ReplyDraft[]> {
    try {
      return await withPreferencesStore<ReplyDraft[]>(context, STORE_NAME, (store) => {
        const parsed = readJsonArray<ReplyDraft>(store, KEY_REPLY_DRAFTS, [])
        return DraftSettings.parseReplyDrafts(parsed)
      })
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read draft')
    }
  }

  private static async writeAllReplyDrafts(context: common.UIAbilityContext, drafts: ReplyDraft[]): Promise<void> {
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        writeJsonValue<ReplyDraft[]>(store, KEY_REPLY_DRAFTS, drafts)
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save draft')
    }
  }

  private static async loadAllComposeDrafts(context: common.UIAbilityContext): Promise<ComposeDraft[]> {
    try {
      return await withPreferencesStore<ComposeDraft[]>(context, STORE_NAME, (store) => {
        const parsed = readJsonArray<ComposeDraft>(store, KEY_COMPOSE_DRAFTS, [])
        return DraftSettings.parseComposeDrafts(parsed)
      })
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read draft')
    }
  }

  private static async writeAllComposeDrafts(context: common.UIAbilityContext, drafts: ComposeDraft[]): Promise<void> {
    try {
      await withPreferencesStore<void>(context, STORE_NAME, (store) => {
        writeJsonValue<ComposeDraft[]>(store, KEY_COMPOSE_DRAFTS, drafts)
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save draft')
    }
  }

  private static parseComposeDrafts(parsed: ComposeDraft[]): ComposeDraft[] {
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed
      .filter((item: ComposeDraft) => item && item.topicId > 0 && !!item.key && item.content !== undefined)
      .slice(0, MAX_COMPOSE_DRAFTS)
  }

  private static touchLocalData(): void {
    // Pure-V2: bump the local-data-changed signal mirror (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = Date.now()
  }

  private static parseReplyDrafts(parsed: ReplyDraft[]): ReplyDraft[] {
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed
      .filter((item: ReplyDraft) => item && item.topicId > 0 && item.content !== undefined)
      .slice(0, MAX_REPLY_DRAFTS)
  }

  private static parseTopicDraft(parsed: TopicDraft | null): TopicDraft | null {
    if (!parsed) {
      return null
    }
    const draft: TopicDraft = {
      nodeName: (parsed.nodeName ?? '').trim(),
      nodeTitle: (parsed.nodeTitle ?? '').trim(),
      title: (parsed.title ?? '').trim(),
      content: parsed.content ?? '',
      updatedAt: parsed.updatedAt || 0
    }
    if (!draft.nodeName && !draft.title && draft.content.trim().length === 0) {
      return null
    }
    return draft
  }
}
