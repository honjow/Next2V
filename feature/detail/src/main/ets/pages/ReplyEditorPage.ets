import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ReplyComposerCoordinator,
  type ReplyComposerEditResult,
  type ReplyComposerToolbarCommand,
} from '../model/ReplyComposerCoordinator'
import {
  ReplyComposerDraftCoordinator,
  type ReplyComposerDraftState,
} from '../model/ReplyComposerDraftCoordinator'
import {
  ApiService, AppStrings, CookieJarSettings, DateUtils, MarkdownContent, MarkdownToolbar, SecondaryFormScaffold,
  ThemeConstants
} from 'shared'

@Component
export struct ReplyEditorPage {
  @Prop topicId: number = 0
  @Prop topicTitle: string = ''
  @Prop initialContent: string = ''
  @Consume('ns') stack: NavPathStack

  @State private content: string = ''
  @State private isPreview: boolean = false
  @State private errorMessage: string = ''
  @State private savedAt: number = 0
  @State private isSubmitting: boolean = false
  @State private isSubmitDialogShown: boolean = false
  @State private contentSelectionStart: number = 0
  @State private contentSelectionEnd: number = 0
  @State private submitContentSnapshot: string = ''

  private contentController: TextAreaController = new TextAreaController()
  private saveTimerId: number = 0
  private isSaving: boolean = false
  private hasSubmitted: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.applyDraftState(ReplyComposerDraftCoordinator.initialState())
    this.isPreview = false
    this.isSubmitting = false
    this.isSubmitDialogShown = false
    this.submitContentSnapshot = ''
    this.hasSubmitted = false

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.loadDraft(context, this.topicId, this.initialContent)
      .then((state: ReplyComposerDraftState) => {
        this.applyDraftState(state)
        if (state.shouldScheduleSave) {
          this.scheduleSaveDraft()
        }
      })
  }

  aboutToDisappear(): void {
    this.clearSaveTimer()
    if (!this.hasSubmitted) {
      this.persistDraft()
    }
  }

  build() {
    Column() {
      SecondaryFormScaffold({ includeKeyboardPadding: true }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        if (this.topicTitle) {
          Text(this.topicTitle)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        MarkdownToolbar({
          previewActive: this.isPreview,
          onEdit: () => { this.isPreview = false },
          onPreview: () => { this.isPreview = true },
          onBold: () => { this.applyToolbarCommand('bold') },
          onItalic: () => { this.applyToolbarCommand('italic') },
          onCode: () => { this.applyToolbarCommand('code') },
          onQuote: () => { this.applyToolbarCommand('quote') },
          onList: () => { this.applyToolbarCommand('list') },
          onLink: () => { this.applyToolbarCommand('link') },
          onImage: () => { this.applyToolbarCommand('image') },
          onClear: () => { this.confirmClearDraft() }
        })

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
        }

        if (!this.isPreview) {
          TextArea({ placeholder: '写回复（自动保存草稿）', text: this.content, controller: this.contentController })
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .height(320)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .onChange((value: string) => {
              this.content = value
              this.scheduleSaveDraft()
            })
            .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
              this.contentSelectionStart = selectionStart
              this.contentSelectionEnd = selectionEnd
            })
        } else {
          if (this.content.trim().length === 0) {
            Text('暂无内容')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .padding({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
          } else {
            Scroll() {
              MarkdownContent({ source: this.content, topMargin: 0 })
            }
            .scrollBar(BarState.Off)
            .height(320)
          }
        }

        if (this.savedAt > 0) {
          Text(AppStrings.format(AppStrings.text($r('app.string.draft_saved_on_format'), 'Saved on {0}'), [DateUtils.toDateString(this.savedAt)]))
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }

        Button(this.isSubmitting ? '提交中...' : '提交')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .width('100%')
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .enabled(this.canSubmit())
          .onClick(() => { this.confirmSubmit() })
      }
      .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private applyToolbarCommand(command: ReplyComposerToolbarCommand): void {
    const result = ReplyComposerCoordinator.applyToolbarCommand(
      command,
      this.content,
      this.contentSelectionStart,
      this.contentSelectionEnd,
    )
    this.applyEditResult(result)
    this.isPreview = false
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(result.caret)
    }, 0)
  }

  private applyEditResult(result: ReplyComposerEditResult): void {
    this.content = result.content
    this.contentSelectionStart = result.selectionStart
    this.contentSelectionEnd = result.selectionEnd
  }

  private scheduleSaveDraft(): void {
    this.clearSaveTimer()
    this.saveTimerId = setTimeout(() => {
      this.persistDraft()
    }, 500)
  }

  private clearSaveTimer(): void {
    if (this.saveTimerId) {
      clearTimeout(this.saveTimerId)
      this.saveTimerId = 0
    }
  }

  private persistDraft(): void {
    if (this.isSaving || !ReplyComposerDraftCoordinator.shouldPersist(this.topicId, this.hasSubmitted)) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.persistDraft(context, this.topicId, this.content)
      .then((savedAt: number) => {
        this.savedAt = savedAt
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存草稿失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }

  private confirmClearDraft(): void {
    if (this.isSaving) {
      return
    }
    if (this.content.trim().length === 0) {
      this.clearDraft()
      return
    }
    this.getUIContext().showAlertDialog({
      title: '清空草稿',
      message: '确定清空当前草稿吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: () => { this.clearDraft() }
      }
    })
  }

  private clearDraft(): void {
    this.content = ''
    this.contentSelectionStart = 0
    this.contentSelectionEnd = 0
    this.savedAt = 0
    this.clearSaveTimer()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.clearDraft(context, this.topicId)
      .then(() => {
        promptAction.openToast({ message: $r('app.string.common_cleared') }).catch((_error: Error) => { })
      })
      .catch((_error: Error) => {
        promptAction.openToast({ message: '清空失败' }).catch((_error2: Error) => { })
      })
  }

  private canSubmit(): boolean {
    return ReplyComposerCoordinator.canSubmitWithCookie(
      this.isSubmitting,
      this.isSubmitDialogShown,
      this.topicId,
      this.content,
      CookieJarSettings.getCurrentCookie(),
    )
  }

  private applyDraftState(state: ReplyComposerDraftState): void {
    this.content = state.content
    this.savedAt = state.savedAt
    this.errorMessage = state.errorMessage
    this.contentSelectionStart = state.selectionStart
    this.contentSelectionEnd = state.selectionEnd
  }

  private confirmSubmit(): void {
    const check = ReplyComposerCoordinator.checkSubmit(
      this.isSubmitting,
      this.isSubmitDialogShown,
      this.topicId,
      this.content,
      CookieJarSettings.getCurrentCookie(),
    )
    if (check.reason === 'busy' || check.reason === 'invalidTopic') {
      return
    }
    if (check.reason === 'empty' || check.reason === 'loginRequired') {
      promptAction.openToast({ message: check.message }).catch((_error: Error) => { })
      return
    }
    this.submitContentSnapshot = check.content
    this.isSubmitDialogShown = true
    this.persistDraft()
    this.getUIContext().showAlertDialog({
      title: '提交回复',
      message: ReplyComposerCoordinator.pageSubmitConfirmMessage(this.topicTitle),
      primaryButton: { value: '取消', action: () => { this.isSubmitDialogShown = false } },
      secondaryButton: { value: '提交', action: () => { this.submit() } }
    })
  }

  private submit(): void {
    if (this.isSubmitting) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.isSubmitDialogShown = false
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => { })
      return
    }
    this.isSubmitting = true
    this.errorMessage = ''
    const cleanContent = this.submitContentSnapshot || this.content.trim()
    this.api.submitReplyWithCookie(cookie, this.topicId, cleanContent)
      .then(() => {
        this.hasSubmitted = true
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        ReplyComposerDraftCoordinator.clearDraft(context, this.topicId).catch((_error: Error) => { })
        promptAction.openToast({ message: $r('app.string.submit_completed') }).catch((_error: Error) => { })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '提交失败'
        promptAction.openToast({ message: this.errorMessage }).catch((_error2: Error) => { })
      })
      .finally(() => {
        this.isSubmitting = false
        this.isSubmitDialogShown = false
      })
  }
}
