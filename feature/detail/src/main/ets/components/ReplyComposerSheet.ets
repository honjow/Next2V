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
  AppStrings,
  connectLayoutSafeArea,
  CookieJarSettings,
  DateUtils,
  LayoutSafeAreaState,
  MarkdownContent,
  MarkdownToolbar,
  AppModalScaffold,
  ThemeConstants,
  translateApiError
} from 'shared'

@ComponentV2
export struct ReplyComposerSheet {
  @Param topicId: number = 0
  @Param topicTitle: string = ''
  @Param initialContent: string = ''
  // Keyboard height is published into AppStorageV2 by EntryAbility
  // (formerly a V1 @StorageProp); drives composerBodyHeight().
  layout: LayoutSafeAreaState = connectLayoutSafeArea()

  @Event closeAction?: () => void
  // Emits a clean (trimmed) content snapshot to the parent page. The parent owns the network
  // submit: it closes this sheet first (so the TextArea can't re-grab focus / re-open the
  // keyboard during the pending request) and opens the system LoadingDialog.
  @Event submitAction?: (content: string) => void

  @Local private content: string = ''
  @Local private isPreview: boolean = false
  @Local private errorMessage: string = ''
  @Local private savedAt: number = 0
  @Local private isSubmitting: boolean = false
  @Local private isSubmitDialogShown: boolean = false
  @Local private contentSelectionStart: number = 0
  @Local private contentSelectionEnd: number = 0

  private contentController: TextAreaController = new TextAreaController()
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

  @Monitor('initialContent')
  onInitialContentChanged(): void {
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
    return ReplyComposerCoordinator.composerBodyHeight(this.layout.keyboardHeight)
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
    // Ordinary reply submit deliberately SKIPS the "Submit this reply?" confirmation dialog.
    // Persist the draft (so a failed parent submit keeps the user's text), then emit the clean
    // snapshot to the parent. The parent closes this sheet immediately, opens the system
    // LoadingDialog, then runs the network submit — closing first stops the TextArea from
    // re-grabbing focus and re-opening the soft keyboard mid-request. Auth/2FA/session errors
    // are surfaced by the parent's failure handler, never converted into a confirmation bypass.
    this.errorMessage = ''
    this.persistDraft()
    if (this.submitAction) {
      this.submitAction(check.content)
    }
  }

  private close(): void {
    this.persistDraft()
    if (this.closeAction) {
      this.closeAction()
    }
  }
}
