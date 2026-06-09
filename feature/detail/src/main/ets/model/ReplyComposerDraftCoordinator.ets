import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  DraftSettings,
} from 'shared'
import { ReplyComposerCoordinator } from './ReplyComposerCoordinator'

export interface ReplyComposerDraftState {
  content: string
  savedAt: number
  errorMessage: string
  selectionStart: number
  selectionEnd: number
  shouldScheduleSave: boolean
}

export class ReplyComposerDraftCoordinator {
  static initialState(): ReplyComposerDraftState {
    return {
      content: '',
      savedAt: 0,
      errorMessage: '',
      selectionStart: 0,
      selectionEnd: 0,
      shouldScheduleSave: false,
    }
  }

  static async loadDraft(
    context: common.UIAbilityContext,
    topicId: number,
    initialContent: string,
  ): Promise<ReplyComposerDraftState> {
    try {
      const draft = await DraftSettings.loadReplyDraft(context, topicId)
      const seed = ReplyComposerCoordinator.normalizeInitialContent(initialContent)
      const draftContent = draft ? (draft.content || '') : ''
      const content = ReplyComposerCoordinator.mergeInitialContent(draftContent, seed)
      return {
        content: content,
        savedAt: draft ? (draft.updatedAt || 0) : 0,
        errorMessage: '',
        selectionStart: content.length,
        selectionEnd: content.length,
        shouldScheduleSave: !!seed && content !== draftContent,
      }
    } catch (error) {
      const e = error as Error
      return {
        content: '',
        savedAt: 0,
        errorMessage: e.message || AppStrings.text($r('app.string.draft_load_failed'), 'Failed to load draft'),
        selectionStart: 0,
        selectionEnd: 0,
        shouldScheduleSave: false,
      }
    }
  }

  static shouldPersist(topicId: number, hasSubmitted: boolean): boolean {
    return topicId > 0 && !hasSubmitted
  }

  static async persistDraft(
    context: common.UIAbilityContext,
    topicId: number,
    content: string,
  ): Promise<number> {
    await DraftSettings.saveReplyDraft(context, topicId, content)
    return Math.floor(Date.now() / 1000)
  }

  static clearDraft(context: common.UIAbilityContext, topicId: number): Promise<void> {
    return DraftSettings.clearReplyDraft(context, topicId)
  }
}
