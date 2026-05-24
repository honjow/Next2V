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
  ApiService,
  AppStrings,
  CookieJarSettings,
  DateUtils,
  MarkdownContent,
  MarkdownToolbar,
  AppModalScaffold,
  StorageKeys,
  ThemeConstants,
  translateApiError
} from 'shared'

@Component
export struct ReplyComposerSheet {
  @Prop topicId: number = 0
  @Prop topicTitle: string = ''
  @Prop @Watch('onInitialContentChanged') initialContent: string = ''
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0

  closeAction?: () => void
  submittedAction?: () => void

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
  private api: ApiService = new ApiService()
  private saveTimerId: number = 0
  private hasSubmitted: boolean = false

  aboutToAppear(): void {
    this.loadDraft()
  }

  aboutToDisappear(): void {
    this.clearSaveTimer()
    if (!this.hasSubmitted) {
      this.persistDraft()
    }
  }

  onInitialContentChanged(_propName: string): void {
    const seed = ReplyComposerCoordinator.normalizeInitialContent(this.initialContent)
    if (!seed) {
      return
    }
    const nextContent = ReplyComposerCoordinator.mergeInitialContent(this.content, seed)
    if (nextContent === this.content) {
      return
    }
    this.content = nextContent
    this.isPreview = false
    this.contentSelectionStart = this.content.length
    this.contentSelectionEnd = this.content.length
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(this.content.length)
    }, 0)
  }

  build() {
    AppModalScaffold({
      title: AppStrings.text(AppStrings.R_REPLY_COMPOSER_TITLE, 'Write reply'),
      compact: true,
      includeKeyboardPadding: true,
      closeAction: () => {
        this.close()
      }
    }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (ReplyComposerCoordinator.shouldShowTopicTitle(this.topicTitle)) {
            Text(this.topicTitle)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Row({ space: ThemeConstants.SPACE_SM }) {
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
              .layoutWeight(1)

            Button(ReplyComposerCoordinator.submitButtonLabel(this.isSubmitting), { type: ButtonType.Capsule })
              .fontSize(ThemeConstants.FONT_SIZE_TAG)
              .fontWeight(FontWeight.Medium)
              .height(32)
              .width(76)
              .enabled(this.canSubmit())
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .onClick(() => { this.confirmSubmit() })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
          }

          if (this.isPreview) {
            if (this.content.trim().length === 0) {
              Text(ReplyComposerCoordinator.previewEmptyMessage())
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .height(this.composerBodyHeight())
                .width('100%')
            } else {
              Scroll() {
                MarkdownContent({ source: this.content, topMargin: 0 })
              }
              .height(this.composerBodyHeight())
              .width('100%')
              .scrollBar(BarState.Off)
            }
          } else {
            TextArea({ placeholder: AppStrings.text(AppStrings.R_REPLY_BODY_PLACEHOLDER, 'Reply body (auto-saved)'), text: this.content, controller: this.contentController })
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .height(this.composerBodyHeight())
              .width('100%')
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
          }

          if (this.savedAt > 0) {
            Text(this.savedAtText())
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        .width('100%')
      }
    }
  }

  private loadDraft(): void {
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
    }, 600)
  }

  private clearSaveTimer(): void {
    if (this.saveTimerId > 0) {
      clearTimeout(this.saveTimerId)
      this.saveTimerId = 0
    }
  }

  private persistDraft(): void {
    if (!ReplyComposerDraftCoordinator.shouldPersist(this.topicId, this.hasSubmitted)) {
      return
    }
    this.clearSaveTimer()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.persistDraft(context, this.topicId, this.content)
      .then((savedAt: number) => {
        this.savedAt = savedAt
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
  }

  private confirmClearDraft(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_REPLY_CLEAR_DRAFT_TITLE, 'Clear draft'),
      message: AppStrings.text(AppStrings.R_REPLY_CLEAR_DRAFT_MESSAGE, 'Clear this reply draft?'),
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { } },
      secondaryButton: {
        value: AppStrings.text($r('app.string.common_clear'), 'Clear'),
        action: () => {
          this.content = ''
          this.savedAt = 0
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext
          ReplyComposerDraftCoordinator.clearDraft(context, this.topicId).catch((_error: Error) => { })
        }
      }
    })
  }

  private applyDraftState(state: ReplyComposerDraftState): void {
    this.content = state.content
    this.savedAt = state.savedAt
    this.errorMessage = state.errorMessage
    this.contentSelectionStart = state.selectionStart
    this.contentSelectionEnd = state.selectionEnd
  }

  private canSubmit(): boolean {
    return ReplyComposerCoordinator.canSubmit(
      this.isSubmitting,
      this.isSubmitDialogShown,
      this.topicId,
      this.content,
    )
  }

  private composerBodyHeight(): number {
    return ReplyComposerCoordinator.composerBodyHeight(this.keyboardH)
  }

  private savedAtText(): string {
    return ReplyComposerCoordinator.savedAtText(
      this.savedAt,
      (value: number) => DateUtils.toDateString(value),
    )
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
    if (check.reason === 'empty') {
      this.errorMessage = check.message
      promptAction.openToast({ message: check.message }).catch((_error: Error) => { })
      return
    }
    if (check.reason === 'loginRequired') {
      this.errorMessage = check.message
      return
    }
    this.submitContentSnapshot = check.content
    this.isSubmitDialogShown = true
    this.persistDraft()
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_REPLY_CONFIRM_SUBMIT_TITLE, 'Submit reply'),
      message: ReplyComposerCoordinator.sheetSubmitConfirmMessage(),
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { this.isSubmitDialogShown = false } },
      secondaryButton: { value: AppStrings.text($r('app.string.reply_submit'), 'Submit'), action: () => { this.submitReply() } }
    })
  }

  private submitReply(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.isSubmitting) {
      this.isSubmitDialogShown = false
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
        promptAction.openToast({ message: $r('app.string.reply_submitted') }).catch((_error: Error) => { })
        if (this.submittedAction) {
          this.submittedAction()
        }
        this.close()
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
      .finally(() => {
        this.isSubmitting = false
        this.isSubmitDialogShown = false
      })
  }

  private close(): void {
    this.persistDraft()
    if (this.closeAction) {
      this.closeAction()
    }
  }
}
