import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService, AppStrings, connectNavStack, connectNodePickAction, CookieJarSettings, DateUtils, DraftSettings, MarkdownContent, MarkdownToolbar,
  NodePickActionState, SecondaryFormScaffold, ThemeConstants, TopicDetailParams, translateApiError
} from 'shared'

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
  private saveTimerId: number = 0
  private isSaving: boolean = false
  private hasSubmitted: boolean = false
  private api: ApiService = new ApiService()
  // Node-pick command bus: NodePickerPage publishes the chosen node here; we react below.
  private nodePick: NodePickActionState = connectNodePickAction()

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

  aboutToAppear(): void {
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

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        if (draft) {
          this.nodeName = draft.nodeName || ''
          this.nodeTitle = draft.nodeTitle || ''
          this.title = draft.title || ''
          this.content = draft.content || ''
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
    this.clearSaveTimer()
    if (!this.hasSubmitted) {
      this.persistDraft()
    }
  }

  build() {
    Column() {
      SecondaryFormScaffold({ includeKeyboardPadding: true }) {
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
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(ThemeConstants.RADIUS_MD)
          .onChange((value: string) => {
            this.title = value
            this.scheduleSaveDraft()
          })

        MarkdownToolbar({
          previewActive: this.isPreview,
          onEdit: () => { this.isPreview = false },
          onPreview: () => { this.isPreview = true },
          onBold: () => { this.insertInlineMarkdown('**', '**', AppStrings.text(AppStrings.R_MARKDOWN_PLACEHOLDER_TEXT, 'Text')) },
          onItalic: () => { this.insertInlineMarkdown('*', '*', AppStrings.text(AppStrings.R_MARKDOWN_PLACEHOLDER_TEXT, 'Text')) },
          onCode: () => { this.insertInlineMarkdown('`', '`', AppStrings.text(AppStrings.R_MARKDOWN_PLACEHOLDER_CODE, 'Code')) },
          onQuote: () => { this.insertLinePrefix('> ') },
          onList: () => { this.insertLinePrefix('- ') },
          onLink: () => {
            const textHolder = AppStrings.text(AppStrings.R_MARKDOWN_PLACEHOLDER_TEXT, 'Text')
            this.insertInlineMarkdown('[', '](https://)', textHolder, 1 + textHolder.length + '](https://'.length)
          },
          onImage: () => { this.insertImageLinkTemplate() }
        })

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
        }

        if (!this.isPreview) {
          TextArea({ placeholder: AppStrings.text(AppStrings.R_EDITOR_BODY_PLACEHOLDER, 'Body (Markdown)'), text: this.content, controller: this.contentController })
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .height(320)
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
        } else {
          // One fixed-height (= the edit TextArea's 320) top-left container for BOTH the empty hint
          // and the rendered content, so switching edit<->preview never shifts the layout below,
          // regardless of how little content there is.
          Scroll() {
            Column() {
              if (this.content.trim().length === 0) {
                Text(AppStrings.text(AppStrings.R_EDITOR_EMPTY_PREVIEW, 'No content yet'))
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
              } else {
                MarkdownContent({ source: this.content, topMargin: 0 })
              }
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
          .height(320)
        }

        if (this.savedAt > 0) {
          Text(AppStrings.format(AppStrings.text($r('app.string.draft_saved_on_format'), 'Saved on {0}'), [DateUtils.toDateString(this.savedAt)]))
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }

        Button(this.isSubmitting ? AppStrings.text(AppStrings.R_EDITOR_SUBMITTING, 'Submitting...') : AppStrings.text(AppStrings.R_EDITOR_SUBMIT, 'Submit'))
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .width('100%')
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .enabled(this.canSubmit())
          .onClick(() => { this.confirmSubmit() })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private insertImageLinkTemplate(): void {
    const imgHolder = AppStrings.text(AppStrings.R_MARKDOWN_PLACEHOLDER_IMAGE, 'Image')
    this.insertInlineMarkdown('![', '](https://)', imgHolder, 2 + imgHolder.length + '](https://'.length)
  }

  private insertInlineMarkdown(prefix: string, suffix: string, placeholder: string, caretOffset: number = -1): void {
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.contentSelectionStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.contentSelectionEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    const selected = this.content.substring(start, end)
    const middle = selected || placeholder
    const insertion = `${prefix}${middle}${suffix}`
    this.content = `${this.content.substring(0, start)}${insertion}${this.content.substring(end)}`
    const caret = start + (caretOffset >= 0 ? caretOffset : prefix.length + middle.length + suffix.length)
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.isPreview = false
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(caret)
    }, 0)
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
    setTimeout(() => {
      this.contentController.caretPosition(caret)
    }, 0)
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
    if (!this.nodeName.trim() || !this.title.trim() || this.content.trim().length === 0) {
      return false
    }
    return !!CookieJarSettings.getCurrentCookie()
  }

  private confirmSubmit(): void {
    if (this.isSubmitting) {
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
