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
  BUILTIN_STICKERS,
  connectLayoutSafeArea,
  connectNavStack,
  CookieJarSettings,
  ImageBytesUtils,
  ImageUploadErrorCode,
  ImageUploadService,
  ImageUploadSettings,
  LayoutSafeAreaState,
  connectReplyStickerPanel,
  ReplyStickerPanelState,
  StickerPickerPanel,
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
  // Chat-app style sticker panel: tapping the sticker button dismisses the IME and shows the sticker grid
  // in the keyboard's footprint (the page drops the bar to the bottom once keyboardHeight hits 0).
  @Local private showStickerPanel: boolean = false;

  // Keyboard/safe-area metrics (published by EntryAbility). When the keyboard is down, the bar drops
  // to the screen bottom and extends its background over the bottom safe area (see bottomSafePad).
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  // Last non-zero keyboard height, so the sticker panel can take roughly the keyboard's footprint and the
  // bar doesn't jump in height when swapping keyboard -> panel.
  @Local private lastKeyboardHeight: number = 0;
  // Mirror of showStickerPanel published to the nav shell so a system back press closes the panel (instead
  // of popping the topic page) — Index.onBackPressed flips this to false, and the @Monitor below reacts.
  @Local private panelBus: ReplyStickerPanelState = connectReplyStickerPanel();

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
    this.panelBus.open = false
    this.loadDraft()
    // Auto-focus the field so the keyboard opens immediately on open (common reply-UI behavior).
    // Deferred a frame so the TextArea is mounted before requesting focus.
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus(ReplyComposerBar.INPUT_ID)
    }, 80)
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.panelBus.open = false
    this.clearSaveTimer()
    if (!this.hasSubmitted) {
      this.persistDraft()
    }
  }

  // Back press (intercepted by Index.onBackPressed) flips panelBus.open to false to close the panel; mirror
  // that into the local UI state.
  @Monitor('panelBus.open')
  onPanelBusChanged(): void {
    if (!this.panelBus.open && this.showStickerPanel) {
      this.setStickerPanel(false)
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

  @Monitor('layout.keyboardHeight')
  onKeyboardHeightChanged(): void {
    if (this.layout.keyboardHeight > 0) {
      this.lastKeyboardHeight = this.layout.keyboardHeight
    }
  }

  build() {
    Column() {
      // Input area (horizontally padded). The sticker panel below is a full-width sibling so it can bleed to
      // the screen edges, instead of being inset by this padding.
      Column({ space: ThemeConstants.SPACE_XS }) {
        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
            .width('100%')
        }
        // Top row: full-width input with an overlaid clear (×) button vertically centered at the right, shown
        // only when it has content. Symmetric 12+12 vertical padding keeps a single line vertically centered.
        Stack({ alignContent: Alignment.End }) {
          TextArea({
            placeholder: AppStrings.text(
              AppStrings.R_REPLY_BODY_PLACEHOLDER,
              'Reply body (auto-saved)',
            ),
            text: this.content,
            controller: this.contentController,
          })
            .id(ReplyComposerBar.INPUT_ID)
            .width('100%')
            .constraintSize({ maxHeight: 148 })
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .padding({
              top: ThemeConstants.SPACE_MD,
              bottom: ThemeConstants.SPACE_MD,
              left: ThemeConstants.SPACE_MD + ThemeConstants.SPACE_XS,
              right: ThemeConstants.SPACE_MD + ThemeConstants.SPACE_XS,
            })
            .placeholderFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Normal })
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .defaultFocus(true)
            .onChange((value: string) => {
              this.content = value
              this.scheduleSaveDraft()
            })
            // Track the caret so an inserted sticker/image URL lands where the user is typing (the picker blurs
            // the field, so we rely on the last recorded position, not live focus).
            .onTextSelectionChange((start: number, end: number) => {
              this.selStart = start
              this.selEnd = end
            })
            // When the IME re-opens (user taps the field), drop the sticker panel so the two don't stack.
            .onEditChange((isEditing: boolean) => {
              if (isEditing && this.showStickerPanel) {
                this.setStickerPanel(false)
                this.panelBus.open = false
              }
            })
          // Clear button at the input's top-right; only when there's content. focusOnTouch(false) keeps the
          // TextArea focused (keyboard stays up) so the user can immediately retype.
          if (this.content.length > 0) {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(18)
              .fontColor([$r('sys.color.font_secondary')])
              .padding(ThemeConstants.SPACE_XS)
              .margin({ right: ThemeConstants.SPACE_XS })
              .focusOnTouch(false)
              .onClick(() => {
                this.clearContent()
              })
          }
        }.width('100%')

        // Bottom row: action toolbar. Sticker + image on the left, send on the right — keeps the input roomy
        // and the controls from crowding the field's edge.
        Row({ space: ThemeConstants.SPACE_SM }) {
          // Sticker button: toggles the chat-app style panel (dismisses the IME and shows the grid in its
          // place). focusOnTouch(false) so tapping it doesn't re-grab the TextArea caret/keyboard.
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.face_smiling'))
              .fontSize(22)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .width(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
          .height(ReplyComposerBar.REPLY_BAR_CONTROL_SIZE)
          .enabled(!this.isSubmitting)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .focusOnTouch(false)
          .accessibilityText(
            AppStrings.text($r('app.string.sticker_insert_action'), 'Insert sticker'),
          )
          .onClick(() => {
            this.toggleStickerPanel()
          })
          // Image button: pick → upload to the configured host → insert the bare URL at the caret.
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.picture'))
              .fontSize(22)
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
          Blank().layoutWeight(1)
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
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: ThemeConstants.SPACE_SM,
        // Keep the SAME SPACE_SM bottom gap in both states so the bar does NOT jump when swapping
        // keyboard <-> panel (keyboard-up resolves to SPACE_SM since bottomSafePad()=0 then). Only the
        // safe-area inset is conditional: when the panel is open IT owns the bottom (bleeds to the edge),
        // so the input area drops the gesture-bar inset; a keyboard-down bar (no panel) keeps it to cover
        // the gesture area. Dropping the SPACE_SM too (the old `? 0`) shifted the bar ~8vp = a visible jump.
        bottom: this.showStickerPanel
          ? ThemeConstants.SPACE_SM
          : ThemeConstants.SPACE_SM + this.bottomSafePad(),
      })

      // Sticker panel: full-bleed — full screen width (it's outside the input area's horizontal padding) and
      // it extends to the bottom edge (its own bottom safe-area inset keeps the last row above the gesture
      // bar). Shown where the keyboard was, sized to the last keyboard footprint so the bar doesn't jump.
      if (this.showStickerPanel) {
        StickerPickerPanel({
          stickers: BUILTIN_STICKERS,
          panelHeight: this.stickerPanelHeight(),
          onPick: (name: string) => {
            this.insertSticker(name)
          },
        })
      }
    }
    .width('100%')
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

  // Insert text at the last recorded caret/selection, then move the caret past it. refocus=false skips the
  // focus/keyboard grab (used by sticker inserts from the panel, which must keep the IME down + panel open).
  private insertTextAtCaret(text: string, refocus: boolean = true): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.selStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.selEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    this.content = `${this.content.substring(0, start)}${text}${this.content.substring(end)}`
    const caret = start + text.length
    this.selStart = caret
    this.selEnd = caret
    this.scheduleSaveDraft()
    if (refocus) {
      this.moveCaret(caret)
    }
  }

  private toggleStickerPanel(): void {
    if (this.showStickerPanel) {
      this.setStickerPanel(false)
      this.panelBus.open = false
      // Bring the keyboard back when toggling off.
      this.getUIContext().getFocusController().requestFocus(ReplyComposerBar.INPUT_ID)
    } else {
      // Dismiss the IME first; the page's composerLift drops the bar to the bottom once keyboardHeight is 0,
      // and the panel takes the freed space.
      this.contentController.stopEditing()
      this.setStickerPanel(true)
      this.panelBus.open = true
    }
  }

  // Show/hide the sticker panel. Kept as a plain toggle: the bar's vertical position is driven by the page's
  // system-keyboard avoidance (composerLift padding on TopicDetailPage), which is outside this component, so
  // wrapping the panel in animateTo only animated the panel while the bar snapped — a desynced "jump" that
  // looked worse than an instant swap. A correct slide needs the bottom keyboard/panel region restructured
  // into one animatable container; deferred.
  private setStickerPanel(open: boolean): void {
    this.showStickerPanel = open
  }

  // Take roughly the keyboard's footprint (so the bar doesn't jump); fall back before any keyboard shows.
  private stickerPanelHeight(): number {
    // Full keyboard footprint — the panel now bleeds to the bottom edge and insets its own content past the
    // gesture bar, so we no longer subtract the bottom safe area here (that subtraction left a gap below).
    return this.lastKeyboardHeight > 200 ? this.lastKeyboardHeight : 320
  }

  private insertSticker(name: string): void {
    // Insert the readable code "[name]" (not the URL) so the field stays editable; codes are expanded to bare
    // whitelisted URLs only at submit (expandStickerCodes). Don't refocus — keep the panel open for rapid
    // inserts.
    this.insertTextAtCaret(`[${name}]`, false)
  }

  // Expand sticker codes "[name]" to the bare image URL (+ surrounding spaces so V2EX auto-embeds it) at
  // submit time. Driven by the pack data (always available), so it works even after the composer reopens
  // from a draft that holds codes. Unknown "[...]" tokens are left untouched.
  private expandStickerCodes(text: string): string {
    let result = text
    for (const sticker of BUILTIN_STICKERS) {
      const code = `[${sticker.name}]`
      if (result.indexOf(code) >= 0) {
        result = result.split(code).join(` ${sticker.url} `)
      }
    }
    return result
  }

  private clearContent(): void {
    this.content = ''
    this.selStart = 0
    this.selEnd = 0
    this.scheduleSaveDraft()
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
    // Persist the draft (so a failed parent submit keeps the user's text — with the readable codes intact),
    // then expand sticker codes to bare image URLs and emit the clean snapshot. The parent closes this bar
    // immediately and owns the network submit.
    this.errorMessage = ''
    this.persistDraft()
    if (this.submitAction) {
      this.submitAction(this.expandStickerCodes(check.content))
    }
  }
}
