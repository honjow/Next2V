import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { ReplyComposerCoordinator } from '../model/ReplyComposerCoordinator'
import {
  ReplyComposerDraftCoordinator,
  type ReplyComposerDraftState,
} from '../model/ReplyComposerDraftCoordinator'
import {
  AppStrings,
  connectLayoutSafeArea,
  CookieJarSettings,
  LayoutSafeAreaState,
  ThemeConstants,
  translateApiError,
} from 'shared'

/**
 * Bottom-anchored inline reply composer.
 *
 * Replaces the former half-modal reply sheet: V2EX does not render Markdown in replies (only bare
 * image/video links auto-embed), so the editor is intentionally a plain auto-growing text field with
 * a send button — no Markdown toolbar, no preview. It is shown on demand (the topic page's reply FAB
 * or a per-reply "reply" action), docked above the keyboard by the page, and dismisses on send or
 * tap-outside. Draft auto-save and submit validation reuse the existing coordinators; the page owns
 * the network submit (see TopicDetailPage.submitReplyFromComposer + the reply submit UX contract).
 */
@ComponentV2
export struct ReplyComposerBar {
  @Param topicId: number = 0;
  @Param initialContent: string = '';

  @Event closeAction?: () => void;
  // Emits a clean (trimmed) snapshot to the parent, which owns the network submit. Kept identical to
  // the former sheet so the reply submit UX contract (close-before-request, LoadingDialog, draft
  // preserve/clear) continues to hold.
  @Event submitAction?: (content: string) => void;

  @Local private content: string = '';
  @Local private errorMessage: string = '';
  @Local private isSubmitting: boolean = false;
  // Retained for checkSubmit() signature parity with the page-owned submit path; always false here
  // (the inline bar never shows its own confirmation dialog).
  @Local private isSubmitDialogShown: boolean = false;

  // Keyboard/safe-area metrics (published by EntryAbility). When the keyboard is down, the bar drops
  // to the screen bottom and extends its background over the bottom safe area (see bottomSafePad).
  private layout: LayoutSafeAreaState = connectLayoutSafeArea();

  private contentController: TextAreaController = new TextAreaController();
  private saveTimerId: number = 0;
  private hasSubmitted: boolean = false;

  private static readonly INPUT_ID: string = 'replyComposerBarInput'
  // Shared height for the input field (single line) and the send button so the row lines up flush.
  private static readonly REPLY_BAR_CONTROL_SIZE: number = 40

  aboutToAppear(): void {
    this.loadDraft()
    // Auto-focus the field so the keyboard opens immediately on open (common reply-UI behavior).
    // Deferred a frame so the TextArea is mounted before requesting focus.
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus(ReplyComposerBar.INPUT_ID)
    }, 80)
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
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(this.content.length)
    }, 0)
  }

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        TextArea({
          placeholder: AppStrings.text(
            AppStrings.R_REPLY_BODY_PLACEHOLDER,
            'Reply body (auto-saved)',
          ),
          text: this.content,
          controller: this.contentController,
        })
          .id(ReplyComposerBar.INPUT_ID)
          .layoutWeight(1)
          // Don't use lineHeight/minHeight to force the height: a multi-line TextArea top-aligns its
          // content, so both push the single-line text low. Instead let the box hug its content and
          // use SYMMETRIC vertical padding — that guarantees the text/placeholder stay vertically
          // centered, and 12+12 padding lifts the one-line box to ~40vp to match the send button.
          .constraintSize({ maxHeight: 148 })
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .padding({
            top: ThemeConstants.SPACE_MD,
            bottom: ThemeConstants.SPACE_MD,
            left: ThemeConstants.SPACE_MD + ThemeConstants.SPACE_XS,
            right: ThemeConstants.SPACE_MD + ThemeConstants.SPACE_XS,
          })
          // Match the placeholder font to the input font (placeholder defaults larger), so the field
          // height and baseline don't jump between the empty and typed states.
          .placeholderFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Normal })
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .defaultFocus(true)
          .onChange((value: string) => {
            this.content = value
            this.scheduleSaveDraft()
          })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.paperplane_right_fill'))
            .fontSize(20)
            .fontColor([Color.White])
            // paperplane_right_fill's visual mass sits left of its box center; nudge right to optically
            // center it in the circular button.
            .offset({ x: 2 })
        }
          .width(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
          .height(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
          .enabled(this.canSubmit())
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .accessibilityText(ReplyComposerCoordinator.submitButtonLabel(this.isSubmitting))
          .onClick(() => {
            this.confirmSubmit()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_SM + this.bottomSafePad(),
    })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .border({ width: { top: 0.5 }, color: $r('sys.color.ohos_id_color_list_separator') })
  }

  // When the keyboard is up the page docks the bar on top of it (no bottom inset needed). When the
  // keyboard is down (collapsed via the IME caret/back while the bar stays open), the bar sits at the
  // screen bottom; add the bottom safe-area inset so the bar's background extends over the gesture
  // area instead of leaving a gap that reveals the page content underneath.
  private bottomSafePad(): number {
    return this.layout.keyboardHeight > 0 ? 0 : this.layout.bottomAvoidHeight
  }

  private loadDraft(): void {
    this.applyDraftState(ReplyComposerDraftCoordinator.initialState())
    this.isSubmitting = false
    this.isSubmitDialogShown = false
    this.hasSubmitted = false
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.loadDraft(context, this.topicId, this.initialContent).then(
      (state: ReplyComposerDraftState) => {
        this.applyDraftState(state)
        if (state.shouldScheduleSave) {
          this.scheduleSaveDraft()
        }
      },
    )
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
    ReplyComposerDraftCoordinator.persistDraft(context, this.topicId, this.content).catch(
      (error: Error) => {
        this.errorMessage = translateApiError(error)
      },
    )
  }

  private applyDraftState(state: ReplyComposerDraftState): void {
    this.content = state.content
    this.errorMessage = state.errorMessage
  }

  private canSubmit(): boolean {
    return ReplyComposerCoordinator.canSubmit(
      this.isSubmitting,
      this.isSubmitDialogShown,
      this.topicId,
      this.content,
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
      promptAction.openToast({ message: check.message }).catch((_error: Error) => {})
      return
    }
    if (check.reason === 'loginRequired') {
      this.errorMessage = check.message
      return
    }
    // Persist the draft (so a failed parent submit keeps the user's text), then emit the clean
    // snapshot. The parent closes this bar immediately and owns the network submit.
    this.errorMessage = ''
    this.persistDraft()
    if (this.submitAction) {
      this.submitAction(check.content)
    }
  }
}
