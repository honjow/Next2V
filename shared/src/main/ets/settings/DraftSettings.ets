import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'next2v_drafts'
const KEY_REPLY_DRAFTS: string = 'replyDrafts'
const MAX_REPLY_DRAFTS: number = 50

export interface ReplyDraft {
  topicId: number
  content: string
  updatedAt: number
}

export class DraftSettings {
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
}

