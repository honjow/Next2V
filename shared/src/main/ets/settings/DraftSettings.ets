import { common } from '@kit.AbilityKit'
import { StorageKeys } from '../constants/StorageKeys'
import { deleteKeysAndFlush, readJsonArray, readJsonObject, setAppStorageValue, withPreferencesStore, writeJsonValue } from './SettingsStorage'
import { STORE_NAME_DRAFTS } from './SettingsStores'
import { AppStrings } from '../i18n/AppStrings'

const STORE_NAME: string = STORE_NAME_DRAFTS
const KEY_REPLY_DRAFTS: string = 'replyDrafts'
const KEY_TOPIC_DRAFT: string = 'topicDraft'
const MAX_REPLY_DRAFTS: number = 50

export interface ReplyDraft {
  topicId: number
  content: string
  updatedAt: number
}

export interface TopicDraft {
  nodeName: string
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

  static async saveTopicDraft(context: common.UIAbilityContext, nodeName: string, title: string, content: string): Promise<void> {
    const cleanNode = (nodeName ?? '').trim()
    const cleanTitle = (title ?? '').trim()
    const cleanContent = content ?? ''
    if (!cleanNode && !cleanTitle && cleanContent.trim().length === 0) {
      await DraftSettings.clearTopicDraft(context)
      return
    }
    const draft: TopicDraft = {
      nodeName: cleanNode,
      title: cleanTitle,
      content: cleanContent,
      updatedAt: Math.floor(Date.now() / 1000)
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
        deleteKeysAndFlush(store, [KEY_TOPIC_DRAFT, KEY_REPLY_DRAFTS])
      })
      DraftSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_DRAFT_CLEAR_FAILED, 'Failed to clear drafts'))
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

  private static touchLocalData(): void {
    setAppStorageValue<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, Date.now())
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
