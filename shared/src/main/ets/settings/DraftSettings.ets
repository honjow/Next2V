import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'next2v_drafts'
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
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_TOPIC_DRAFT, '') as string
      if (!raw) {
        return null
      }
      return DraftSettings.parseTopicDraft(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取草稿失败')
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
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TOPIC_DRAFT, JSON.stringify(draft))
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存草稿失败')
    }
  }

  static async clearTopicDraft(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_TOPIC_DRAFT)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清空草稿失败')
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
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_TOPIC_DRAFT)
      store.deleteSync(KEY_REPLY_DRAFTS)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清理草稿失败')
    }
  }

  private static async loadAllReplyDrafts(context: common.UIAbilityContext): Promise<ReplyDraft[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_REPLY_DRAFTS, '[]') as string
      return DraftSettings.parseReplyDrafts(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取草稿失败')
    }
  }

  private static async writeAllReplyDrafts(context: common.UIAbilityContext, drafts: ReplyDraft[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_DRAFTS, JSON.stringify(drafts))
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存草稿失败')
    }
  }

  private static parseReplyDrafts(raw: string): ReplyDraft[] {
    try {
      const parsed = JSON.parse(raw) as ReplyDraft[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed
        .filter((item: ReplyDraft) => item && item.topicId > 0 && item.content !== undefined)
        .slice(0, MAX_REPLY_DRAFTS)
    } catch (error) {
      return []
    }
  }

  private static parseTopicDraft(raw: string): TopicDraft | null {
    try {
      const parsed = JSON.parse(raw) as TopicDraft
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
    } catch (error) {
      return null
    }
  }
}
