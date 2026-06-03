import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { KeyboardAvoidMode, promptAction, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  ApiService, AppStrings, connectLayoutSafeArea, connectNavStack, connectNodePickAction, connectTopicEditorAction, CookieJarSettings, DateUtils, DraftSettings, ImageBytesUtils, ImageUploadErrorCode, ImageUploadService, ImageUploadSettings, LayoutSafeAreaState, MarkdownContent, MarkdownToolbar,
  NodePickActionState, publishTopicEditorSubmitEnabled, ThemeConstants, TopicDetailParams, TopicEditorActionState, translateApiError, type ImageBytes
} from 'shared'

// Body TextArea id, used to move focus into it after a toolbar insert.
const BODY_INPUT_ID: string = 'topicEditorBodyInput'
// Minimum editing area so the body never collapses to nothing when the keyboard shrinks the pane;
// below this the whole form scrolls instead.
const BODY_MIN_HEIGHT: number = 200

@ComponentV2
export struct TopicEditorPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder);
  // used purely as a method target (pushPathByName/pop), so no V2 reactivity is needed.
  private stack: NavPathStack = connectNavStack().stack

  @Local private nodeName: string = ''
  // Display-only label for the picked node (the submit value is nodeName). Empty until a node is
  // picked this session; on a draft reload we only have the name, so the field falls back to it.
  @Local private nodeTitle: string = ''
  @Local private title: string = ''
  @Local private content: string = ''
  @Local private isPreview: boolean = false
  @Local private errorMessage: string = ''
  @Local private savedAt: number = 0
  @Local private isSubmitting: boolean = false
  @Local private contentSelectionStart: number = 0
  @Local private contentSelectionEnd: number = 0

  private contentController: TextAreaController = new TextAreaController()
  // Safe-area / keyboard metrics published by EntryAbility; drives the manual keyboard avoidance
  // now that the editor is a fixed-height column (no scroll scaffold).
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  // xmark-in-circle icon for the title's native clear button, matching the body overlay ✕.
  private titleClearIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark_circle_fill'))
    .fontColor([$r('sys.color.font_secondary')])
  private saveTimerId: number = 0
  private isSaving: boolean = false
  private hasSubmitted: boolean = false
  private api: ApiService = new ApiService()
  // Node-pick command bus: NodePickerPage publishes the chosen node here; we react below.
  private nodePick: NodePickActionState = connectNodePickAction()
  // Submit lives in the Index title bar (icon menu). This command bus carries its taps back here.
  private editorAction: TopicEditorActionState = connectTopicEditorAction()
  // Set true in aboutToDisappear so an image upload that finishes after the editor is popped drops its
  // result instead of writing to a torn-down component.
  private disposed: boolean = false

  // Fill the node field the moment the picker pops back (aboutToAppear does not re-run on pop).
  @Monitor('nodePick.command')
  onNodePicked(): void {
    const picked = (this.nodePick.name || '').trim()
    if (!picked) {
      return
    }
    this.nodeName = picked
    this.nodeTitle = (this.nodePick.title || '').trim()
    this.scheduleSaveDraft()
  }

  // Keep the title-bar Submit icon's enabled state in sync with the form (canSubmit() already factors
  // in isSubmitting and the login cookie).
  @Monitor('nodeName', 'title', 'content', 'isSubmitting')
  onSubmittabilityChange(): void {
    publishTopicEditorSubmitEnabled(this.canSubmit())
  }

  // The title-bar Submit icon was tapped (timestamp-tagged command, so a repeat still fires).
  @Monitor('editorAction.command')
  onSubmitCommand(): void {
    if (this.editorAction.command) {
      this.confirmSubmit()
    }
  }

  aboutToAppear(): void {
    // The editor does its own keyboard avoidance (fixed-height column + manual bottomPad); turn off
    // the inherited system OFFSET so the two don't stack and crush the body. Restored on disappear.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    this.disposed = false
    this.nodeName = ''
    this.nodeTitle = ''
    this.title = ''
    this.content = ''
    this.isPreview = false
    this.errorMessage = ''
    this.savedAt = 0
    this.isSubmitting = false
    this.contentSelectionStart = 0
    this.contentSelectionEnd = 0
    this.hasSubmitted = false
    // Seed the title-bar Submit icon disabled; the @Monitor republishes as the form / draft fills in.
    publishTopicEditorSubmitEnabled(this.canSubmit())

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        if (draft) {
          this.nodeName = draft.nodeName || ''
          this.nodeTitle = draft.nodeTitle || ''
          this.title = draft.title || ''
          this.content = this.stripUploadingPlaceholders(draft.content || '')
          this.savedAt = draft.updatedAt || 0
          this.contentSelectionStart = this.content.length
          this.contentSelectionEnd = this.content.length
        }
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    // Leave the title-bar Submit icon disabled once we're gone (the next destination owns its own bar).
    publishTopicEditorSubmitEnabled(false)
    this.clearSaveTimer()
    if (!this.hasSubmitted) {
      this.persistDraft()
    }
  }

  build() {
    Column() {
      // Offset below the overlaying HdsNavDestination title bar (top safe area + bar height).
      Blank().height(this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
      // Scrollable so a short screen with the keyboard up scrolls instead of crushing the body; the
      // content is at least one viewport tall (minHeight 100%) so on a tall/tablet screen the
      // layoutWeight body fills the pane rather than sitting in a fixed 320 box.
      Scroll() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        // Node is chosen from the node list only (no free text): tapping opens NodePickerPage, and
        // the pick comes back via the node-pick command bus (see onNodePicked).
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.nodeFieldLabel())
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(this.nodeName.trim().length > 0
              ? $r('sys.color.font_primary')
              : $r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width('100%')
        .height(44)
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
        // Distinguish fields from the page by background-color contrast (card surface on the page's
        // sub-background), not border lines — matches the app's overall flat/card style.
        .backgroundColor($r('sys.color.ohos_id_color_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(!this.isSubmitting)
        .onClick(() => { this.openNodePicker() })

        TextInput({ placeholder: AppStrings.text(AppStrings.R_TOPIC_EDITOR_TITLE_PLACEHOLDER, 'Title'), text: this.title })
          .height(44)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          // Match the placeholder to the input/node font; otherwise it falls back to a larger default.
          .placeholderFont({ size: ThemeConstants.FONT_SIZE_BODY })
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(ThemeConstants.RADIUS_MD)
          // Native clear ✕ on the right, shown only while the field is non-empty (INPUT style).
          .cancelButton({ style: CancelButtonStyle.INPUT, icon: this.titleClearIcon })
          .onChange((value: string) => {
            this.title = value
            this.scheduleSaveDraft()
          })

        MarkdownToolbar({
          previewActive: this.isPreview,
          onEdit: () => { this.isPreview = false },
          onPreview: () => { this.isPreview = true },
          onBold: () => { this.insertInlineMarkdown('**', '**') },
          onItalic: () => { this.insertInlineMarkdown('*', '*') },
          onCode: () => { this.insertInlineMarkdown('`', '`') },
          onQuote: () => { this.insertLinePrefix('> ') },
          onList: () => { this.insertLinePrefix('- ') },
          onLink: () => { this.insertInlineMarkdown('[', '](https://)') },
          onImageUpload: () => { this.pickAndUploadImage() },
          onInsertImageLink: () => { this.insertInlineMarkdown('![', '](https://)') }
        })

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
        }

        if (!this.isPreview) {
          // Body fills the pane (layoutWeight) but never below BODY_MIN_HEIGHT, so it grows on
          // tall/tablet screens yet stays usable (and scrolls) when the keyboard is up. A clear ✕
          // overlays the top-right corner only while the body is non-empty.
          Stack({ alignContent: Alignment.TopEnd }) {
            TextArea({ placeholder: AppStrings.text(AppStrings.R_EDITOR_BODY_PLACEHOLDER, 'Body (Markdown)'), text: this.content, controller: this.contentController })
              .id(BODY_INPUT_ID)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .placeholderFont({ size: ThemeConstants.FONT_SIZE_BODY })
              .width('100%')
              .height('100%')
              .backgroundColor($r('sys.color.ohos_id_color_background'))
              .borderRadius(ThemeConstants.RADIUS_MD)
              .onChange((value: string) => {
                this.content = value
                this.scheduleSaveDraft()
              })
              .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
                this.contentSelectionStart = selectionStart
                this.contentSelectionEnd = selectionEnd
              })
            if (this.content.length > 0) {
              SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                .fontSize(20)
                .fontColor([$r('sys.color.font_secondary')])
                .padding(ThemeConstants.SPACE_SM)
                .onClick(() => { this.clearBody() })
            }
          }
          .layoutWeight(1)
          .constraintSize({ minHeight: BODY_MIN_HEIGHT })
          .width('100%')
        } else if (this.content.trim().length === 0) {
          // Empty preview: a centered glyph instead of a text line. Fills the same pane (layoutWeight +
          // minHeight) as the edit box / rendered preview so edit<->preview<->empty never shifts the
          // layout below.
          Column() {
            SymbolGlyph($r('sys.symbol.square_slash'))
              .fontSize(ThemeConstants.ICON_SIZE_PLACEHOLDER)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ minHeight: BODY_MIN_HEIGHT })
          .justifyContent(FlexAlign.Center)
        } else {
          // Same top-left container as the edit box, also filling the pane height, so switching
          // edit<->preview never shifts the layout below.
          Scroll() {
            Column() {
              MarkdownContent({ source: this.content, topMargin: 0 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({
              top: ThemeConstants.SPACE_SM,
              left: ThemeConstants.SPACE_MD,
              right: ThemeConstants.SPACE_MD,
            })
          }
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ minHeight: BODY_MIN_HEIGHT })
        }

        // Submit moved to the title-bar icon (see Index.topicEditorTitleBarOpts); only the
        // last-saved hint remains at the bottom.
        if (this.savedAt > 0) {
          Text(AppStrings.format(AppStrings.text($r('app.string.draft_saved_on_format'), 'Saved on {0}'), [DateUtils.toDateString(this.savedAt)]))
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      // At least one viewport tall so the layoutWeight body fills the pane; taller content (or a
      // shrunk pane when the keyboard is up) overflows and the Scroll takes over.
      .constraintSize({ minHeight: '100%' })
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      Blank().height(this.bottomPad())
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // Bottom inset under the form. When the keyboard is up it already spans the bottom safe area, so
  // pad by just its height (plus a small gap) — adding bottomAvoidHeight too would double-count the
  // nav-bar inset and lift the content further than needed.
  private bottomPad(): number {
    if (this.layout.keyboardHeight > 0) {
      return this.layout.keyboardHeight + ThemeConstants.SPACE_SM
    }
    return this.layout.bottomAvoidHeight + ThemeConstants.SPACE_XL
  }

  private insertInlineMarkdown(prefix: string, suffix: string): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.contentSelectionStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.contentSelectionEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    const selected = this.content.substring(start, end)
    const insertion = `${prefix}${selected}${suffix}`
    this.content = `${this.content.substring(0, start)}${insertion}${this.content.substring(end)}`
    // No placeholder text: with nothing selected the caret lands between the markers so the user just
    // types; when wrapping a selection it lands after the closing marker.
    const caret = selected.length === 0 ? start + prefix.length : start + insertion.length
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.isPreview = false
    this.scheduleSaveDraft()
    this.moveCaret(caret)
  }

  // Setting this.content (a controlled `text:` binding) re-renders the TextArea and resets its caret
  // to the end. That render can land a frame or two later, so focus the body (toolbar buttons keep
  // focus via focusOnTouch) and re-assert the caret across a few ticks to reliably win that race —
  // a single deferred call lands inconsistently, leaving the caret stuck at the end.
  private moveCaret(caret: number): void {
    this.focusBody()
    const apply = () => { this.contentController.caretPosition(caret) }
    setTimeout(apply, 0)
    setTimeout(apply, 50)
  }

  private focusBody(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(BODY_INPUT_ID)
    } catch (_error) {
    }
  }

  private clearBody(): void {
    this.content = ''
    this.contentSelectionStart = 0
    this.contentSelectionEnd = 0
    this.scheduleSaveDraft()
  }

  private async pickAndUploadImage(): Promise<void> {
    // Imgur needs the user's own Client-ID; gate before opening the picker so the user isn't asked to
    // pick an image only to fail.
    const config = ImageUploadSettings.current()
    if (config.provider === 'imgur' && !config.imgurClientId) {
      this.promptConfigureClientId()
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
    // Insert a uniquely-tagged "uploading" placeholder at the caret, then swap it for the final URL (or
    // remove it on failure). Matching the exact captured placeholder string avoids index drift if the
    // user keeps typing during the upload. The `uploading://` scheme renders nothing (not allowlisted),
    // and a stale one is stripped from the draft on next open.
    const uploadingLabel = AppStrings.text(AppStrings.R_IMAGE_UPLOAD_UPLOADING, 'Uploading')
    const placeholder = `![${uploadingLabel}](uploading://${Date.now()})`
    this.insertTextAtCaret(placeholder)
    const fileName = `image.${ImageBytesUtils.extensionFor(image.mimeType)}`
    ImageUploadService.uploadImage(image.bytes, image.mimeType, fileName)
      .then((uploaded) => {
        if (this.disposed) {
          return
        }
        this.replacePlaceholder(placeholder, `![](${uploaded.url})`)
      })
      .catch((error: Error) => {
        if (this.disposed) {
          return
        }
        this.replacePlaceholder(placeholder, '')
        this.handleUploadError(error)
      })
  }

  // Insert a fully-formed string at the caret (mirrors insertInlineMarkdown but for a complete token).
  private insertTextAtCaret(text: string): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.contentSelectionStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.contentSelectionEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    this.content = `${this.content.substring(0, start)}${text}${this.content.substring(end)}`
    const caret = start + text.length
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.isPreview = false
    this.scheduleSaveDraft()
    this.moveCaret(caret)
  }

  // Replace the exact placeholder substring with finalText (empty removes it). Bails if the user already
  // deleted the placeholder.
  private replacePlaceholder(placeholder: string, finalText: string): void {
    const index = this.content.indexOf(placeholder)
    if (index < 0) {
      return
    }
    this.content = `${this.content.substring(0, index)}${finalText}${this.content.substring(index + placeholder.length)}`
    // Update internal selection bookkeeping but do NOT re-focus / re-assert the caret here: this runs
    // from the async upload completion, when the user may have moved to the title field or preview —
    // stealing focus or popping the keyboard then would be a surprising jump. The controlled-text update
    // applies on its own.
    const caret = index + finalText.length
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.scheduleSaveDraft()
  }

  private stripUploadingPlaceholders(text: string): string {
    // Drop any orphaned "uploading…" placeholders a prior session left when the editor closed mid-upload.
    return text.replace(/!\[[^\]]*\]\(uploading:\/\/[0-9]+\)/g, '')
  }

  private handleUploadError(error: Error): void {
    const code = error.message || ''
    if (code === ImageUploadErrorCode.NO_CLIENT_ID) {
      this.promptConfigureClientId()
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

  private promptConfigureClientId(): void {
    this.getUIContext().showAlertDialog({
      message: AppStrings.text(AppStrings.R_IMAGE_UPLOAD_NO_CLIENTID, 'Set your Imgur Client ID first'),
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { } },
      secondaryButton: {
        value: AppStrings.text(AppStrings.R_IMAGE_UPLOAD_GO_CONFIG, 'Configure'),
        action: () => { this.stack.pushPathByName('ImageUploadSettings', null) },
      },
    })
  }

  private showToast(message: string): void {
    promptAction.openToast({ message }).catch((_error: Error) => { })
  }

  private insertLinePrefix(prefix: string): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.contentSelectionStart, 0), contentLength)
    const lineStart = this.content.lastIndexOf('\n', Math.max(0, start - 1)) + 1
    this.content = `${this.content.substring(0, lineStart)}${prefix}${this.content.substring(lineStart)}`
    const caret = start + prefix.length
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.isPreview = false
    this.scheduleSaveDraft()
    this.moveCaret(caret)
  }

  private openNodePicker(): void {
    this.clearSaveTimer()
    this.persistDraft()
    this.stack.pushPathByName('NodePicker', null)
  }

  // Node field text. Bilingual when the display title differs from the (English) node name, e.g.
  // "沙盒 · sandbox"; just the name when there is no distinct title; the prompt when nothing is picked.
  private nodeFieldLabel(): string {
    const name = this.nodeName.trim()
    if (name.length === 0) {
      return AppStrings.text(AppStrings.R_TOPIC_EDITOR_NODE_PLACEHOLDER, 'Node (e.g. create)')
    }
    const title = this.nodeTitle.trim()
    if (title.length === 0 || title.toLowerCase() === name.toLowerCase()) {
      return name
    }
    return `${title} · ${name}`
  }

  private scheduleSaveDraft(): void {
    this.clearSaveTimer()
    this.saveTimerId = setTimeout(() => {
      this.persistDraft()
    }, 600)
  }

  private clearSaveTimer(): void {
    if (this.saveTimerId) {
      clearTimeout(this.saveTimerId)
      this.saveTimerId = 0
    }
  }

  private persistDraft(): void {
    if (this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.saveTopicDraft(context, this.nodeName, this.title, this.content, this.nodeTitle)
      .then((savedAt: number) => {
        this.savedAt = savedAt
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
      })
      .finally(() => {
        this.isSaving = false
      })
  }

  private canSubmit(): boolean {
    if (this.isSubmitting) {
      return false
    }
    if (this.hasUploadInFlight()) {
      return false
    }
    if (!this.nodeName.trim() || !this.title.trim() || this.content.trim().length === 0) {
      return false
    }
    return !!CookieJarSettings.getCurrentCookie()
  }

  // True while an "uploading…" placeholder is still in the body. Blocks Submit so a half-uploaded image's
  // placeholder can never land in the (paid, irreversible) published topic.
  private hasUploadInFlight(): boolean {
    return this.content.indexOf('uploading://') >= 0
  }

  private confirmSubmit(): void {
    if (this.isSubmitting) {
      return
    }
    if (this.hasUploadInFlight()) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_IMAGE_UPLOAD_WAIT, 'Wait for the image to finish uploading') }).catch((_error: Error) => { })
      return
    }
    if (!this.nodeName.trim()) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_node_required'), 'Please choose a node') }).catch((_error: Error) => { })
      return
    }
    if (!this.title.trim()) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_title_required'), 'Please enter a title') }).catch((_error: Error) => { })
      return
    }
    if (this.content.trim().length === 0) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_body_required'), 'Please enter the body') }).catch((_error: Error) => { })
      return
    }
    if (!CookieJarSettings.getCurrentCookie()) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_auth_required'), 'Please sign in') }).catch((_error: Error) => { })
      return
    }
    const cleanNode = this.nodeName.trim()
    const cleanTitle = this.title.trim()
    const message = AppStrings.format(AppStrings.text(AppStrings.R_EDITOR_CONFIRM_POST_FORMAT, 'Post《{1}》in node「{0}」?\n\nV2EX posting usually costs at least 20 copper coins and will change your account state.'), [cleanNode, cleanTitle])
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_EDITOR_CONFIRM_POST_TITLE, 'Confirm post'),
      message: message,
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { } },
      secondaryButton: { value: AppStrings.text(AppStrings.R_EDITOR_PUBLISH, 'Publish'), action: () => { this.submit() } }
    })
  }

  private submit(): void {
    if (this.isSubmitting) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_auth_required'), 'Please sign in') }).catch((_error: Error) => { })
      return
    }
    this.isSubmitting = true
    this.errorMessage = ''
    this.api.createTopicWithCookie(cookie, this.nodeName, this.title, this.content)
      .then((topicId: number) => {
        this.hasSubmitted = true
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        DraftSettings.clearTopicDraft(context).catch((_error: Error) => { })
        promptAction.openToast({ message: topicId > 0 ? AppStrings.format(AppStrings.text($r('app.string.posted_topic_format'), 'Posted: {0}'), [`${topicId}`]) : $r('app.string.posted_topic') }).catch((_error: Error) => { })
        if (topicId > 0) {
          // Auto-open the freshly posted topic (replace the editor in the stack) instead of just
          // popping back to where compose started — going straight to your new topic is less
          // surprising than landing back on the previous page.
          const p: TopicDetailParams = { topicId: topicId }
          this.stack.replacePathByName('TopicDetail', p as Object)
        } else {
          this.stack.pop()
        }
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
        promptAction.openToast({ message: this.errorMessage }).catch((_error2: Error) => { })
      })
      .finally(() => {
        this.isSubmitting = false
      })
  }
}
