import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { promptAction } from '@kit.ArkUI'
import { ReplyComposerCoordinator } from '../model/ReplyComposerCoordinator'
import {
  ReplyComposerDraftCoordinator,
  type ReplyComposerDraftState,
} from '../model/ReplyComposerDraftCoordinator'
import {
  AppStrings,
  connectLayoutSafeArea,
  connectNavStack,
  CookieJarSettings,
  ImageBytesUtils,
  ImageUploadErrorCode,
  ImageUploadService,
  ImageUploadSettings,
  LayoutSafeAreaState,
  ThemeConstants,
  translateApiError,
  type ImageBytes,
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
  // Nav stack (method target only) so a missing image-host credential can route to its settings page.
  private stack: NavPathStack = connectNavStack().stack;
  // Last caret/selection in the field, so an uploaded image's URL is inserted where the user was typing.
  // Tracked via onTextSelectionChange and seeded to the content end on load/seed (insert-at-end default).
  private selStart: number = 0;
  private selEnd: number = 0;
  // Set in aboutToDisappear so an upload that finishes after the bar closes drops its result instead of
  // writing to a torn-down component.
  private disposed: boolean = false;

  private static readonly INPUT_ID: string = 'replyComposerBarInput';
  // Shared height for the input field (single line) and the send button so the row lines up flush.
  private static readonly REPLY_BAR_CONTROL_SIZE: number = 40;

  aboutToAppear(): void {
    this.loadDraft()
    // Auto-focus the field so the keyboard opens immediately on open (common reply-UI behavior).
    // Deferred a frame so the TextArea is mounted before requesting focus.
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus(ReplyComposerBar.INPUT_ID)
    }, 80)
  }

  aboutToDisappear(): void {
    this.disposed = true
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
    this.selStart = this.content.length
    this.selEnd = this.content.length
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
          // Track the caret so an uploaded image's URL lands where the user is typing (the picker blurs
          // the field, so we rely on the last recorded position, not live focus).
          .onTextSelectionChange((start: number, end: number) => {
            this.selStart = start
            this.selEnd = end
          })
        // Secondary (tonal) image button, just left of the emphasized send key: tap → pick an image →
        // upload to the configured image host → insert the bare URL at the caret. focusOnTouch(false)
        // keeps the TextArea's caret so the insert lands where the user was typing.
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
        .height(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
        .enabled(!this.isSubmitting)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .focusOnTouch(false)
        .accessibilityText(
          AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ACTION_NEW, 'Upload a new image'),
        )
        .onClick(() => {
          this.pickAndUploadImage()
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
    // Drop any orphaned "uploading…" placeholder a prior session left when the bar closed mid-upload.
    this.content = this.stripUploadingPlaceholders(state.content)
    this.errorMessage = state.errorMessage
    this.selStart = this.content.length
    this.selEnd = this.content.length
  }

  private async pickAndUploadImage(): Promise<void> {
    // The active host needs its credential (ImgBB key / sm.ms token / Imgur Client-ID); gate before
    // opening the picker so the user isn't asked to choose an image only to fail.
    const config = ImageUploadSettings.current()
    if (!ImageUploadSettings.isConfigured(config)) {
      this.promptConfigureHost()
      return
    }
    let uri: string = ''
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker()
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      // Prefer a compressed copy over the full-resolution original.
      options.isOriginalSupported = false
      const result = await photoPicker.select(options)
      uri = result.photoUris.length > 0 ? result.photoUris[0] : ''
    } catch (_error) {
      // User cancelled or the picker failed — stay silent.
      return
    }
    if (uri) {
      this.uploadPickedImage(uri)
    }
  }

  private uploadPickedImage(uri: string): void {
    let image: ImageBytes = { bytes: new Uint8Array(0), mimeType: '', byteLength: 0 }
    try {
      image = ImageBytesUtils.readImageBytes(uri)
    } catch (error) {
      // readImageBytes throws the TOO_LARGE code for an oversized pick (gated before allocation); any
      // other read failure maps to the generic message.
      const e = error as Error
      this.showToast(this.uploadErrorMessage(e.message || ''))
      return
    }
    // Insert a uniquely-tagged "uploading" placeholder at the caret, then swap it for the final bare URL
    // (or remove it on failure). Matching the exact captured placeholder avoids index drift if the user
    // keeps typing during the upload; a stale one is stripped from the draft on next open.
    const uploadingLabel = AppStrings.text(AppStrings.R_IMAGE_UPLOAD_UPLOADING, 'Uploading')
    const placeholder = `![${uploadingLabel}](uploading://${Date.now()})`
    this.insertTextAtCaret(placeholder)
    const fileName = `image.${ImageBytesUtils.extensionFor(image.mimeType)}`
    ImageUploadService.uploadImage(image.bytes, image.mimeType, fileName)
      .then((uploaded) => {
        if (this.disposed) {
          return
        }
        // Replies are not Markdown (V2EX auto-embeds a bare image URL), so insert the bare URL — not the
        // `![](url)` wrapper the Markdown topic editor uses.
        this.replacePlaceholder(placeholder, uploaded.url)
      })
      .catch((error: Error) => {
        if (this.disposed) {
          return
        }
        this.replacePlaceholder(placeholder, '')
        this.handleUploadError(error)
      })
  }

  // Insert text at the last recorded caret/selection, then move the caret past it.
  private insertTextAtCaret(text: string): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.selStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.selEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    this.content = `${this.content.substring(0, start)}${text}${this.content.substring(end)}`
    const caret = start + text.length
    this.selStart = caret
    this.selEnd = caret
    this.scheduleSaveDraft()
    this.moveCaret(caret)
  }

  // Replace the exact placeholder substring with finalText (empty removes it). Bails if the user already
  // deleted it. Unlike the synchronous insert, this runs from async upload completion — it updates the
  // text/bookkeeping only and does NOT steal focus or re-pop the keyboard, which would be a surprising
  // jump if the user has moved on.
  private replacePlaceholder(placeholder: string, finalText: string): void {
    const index = this.content.indexOf(placeholder)
    if (index < 0) {
      return
    }
    this.content = `${this.content.substring(0, index)}${finalText}${this.content.substring(index + placeholder.length)}`
    const caret = index + finalText.length
    this.selStart = caret
    this.selEnd = caret
    this.scheduleSaveDraft()
  }

  private stripUploadingPlaceholders(text: string): string {
    return text.replace(/!\[[^\]]*\]\(uploading:\/\/[0-9]+\)/g, '')
  }

  private moveCaret(caret: number): void {
    this.getUIContext().getFocusController().requestFocus(ReplyComposerBar.INPUT_ID)
    // The controlled-text update can land a frame or two later; re-assert across a couple of ticks so the
    // caret reliably wins the race and the soft keyboard comes back up at the right spot.
    const apply = () => {
      this.contentController.caretPosition(caret)
    }
    setTimeout(apply, 0)
    setTimeout(apply, 50)
  }

  private showToast(message: string): void {
    promptAction.openToast({ message }).catch((_error: Error) => {})
  }

  private handleUploadError(error: Error): void {
    const code = error.message || ''
    if (code === ImageUploadErrorCode.NO_CREDENTIAL) {
      this.promptConfigureHost()
      return
    }
    this.showToast(this.uploadErrorMessage(code))
  }

  private uploadErrorMessage(code: string): string {
    if (code === ImageUploadErrorCode.TOO_LARGE) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_TOO_LARGE, 'Image is too large')
    }
    if (code === ImageUploadErrorCode.RATE_LIMIT) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_RATE_LIMIT, 'Rate limited')
    }
    if (code === ImageUploadErrorCode.FORBIDDEN) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_FORBIDDEN, 'Upload rejected')
    }
    if (code === ImageUploadErrorCode.SERVER) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_SERVER, 'Server error')
    }
    if (code === ImageUploadErrorCode.NETWORK) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_NETWORK, 'Network error')
    }
    if (code === ImageUploadErrorCode.BAD_IMAGE) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_BAD_IMAGE, 'Unsupported image')
    }
    if (code === ImageUploadErrorCode.UNSUPPORTED_PROVIDER) {
      return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_UNSUPPORTED, 'Unsupported host')
    }
    return AppStrings.text(AppStrings.R_IMAGE_UPLOAD_ERROR_GENERIC, 'Image upload failed')
  }

  private promptConfigureHost(): void {
    this.getUIContext().showAlertDialog({
      message: AppStrings.text(
        AppStrings.R_IMAGE_UPLOAD_NO_CLIENTID,
        'Configure an image host first',
      ),
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: AppStrings.text(AppStrings.R_IMAGE_UPLOAD_GO_CONFIG, 'Configure'),
        action: () => {
          this.stack.pushPathByName('ImageUploadSettings', null)
        },
      },
    })
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
