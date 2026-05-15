import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService, CookieJarSettings, DateUtils, DraftSettings, MarkdownContent, MarkdownToolbar, SecondaryFormScaffold,
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
    this.content = ''
    this.isPreview = false
    this.errorMessage = ''
    this.savedAt = 0
    this.isSubmitting = false
    this.isSubmitDialogShown = false
    this.contentSelectionStart = 0
    this.contentSelectionEnd = 0
    this.submitContentSnapshot = ''
    this.hasSubmitted = false

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadReplyDraft(context, this.topicId)
      .then((draft) => {
        const seed = this.normalizeInitialContent(this.initialContent)
        const draftContent = draft ? (draft.content || '') : ''
        const merged = this.mergeInitialContent(draftContent, seed)
        if (draft) {
          this.content = merged
          this.savedAt = draft.updatedAt || 0
        } else {
          this.content = merged
          this.savedAt = 0
        }
        this.contentSelectionStart = this.content.length
        this.contentSelectionEnd = this.content.length
        if (seed && merged !== draftContent) {
          this.scheduleSaveDraft()
        }
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '读取草稿失败'
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
          onBold: () => { this.insertInlineMarkdown('**', '**', '文字') },
          onItalic: () => { this.insertInlineMarkdown('*', '*', '文字') },
          onCode: () => { this.insertInlineMarkdown('`', '`', '代码') },
          onQuote: () => { this.insertLinePrefix('> ') },
          onList: () => { this.insertLinePrefix('- ') },
          onLink: () => { this.insertInlineMarkdown('[', '](https://)', '文字', '[文字](https://'.length) },
          onImage: () => { this.insertImageLinkTemplate() },
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
          Text(`已保存于 ${DateUtils.toDateString(this.savedAt)}`)
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

  private insertImageLinkTemplate(): void {
    this.insertInlineMarkdown('![', '](https://)', '图片', '![图片](https://'.length)
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

  private normalizeInitialContent(value: string): string {
    const clean = (value || '').trim()
    return clean ? `${clean} ` : ''
  }

  private mergeInitialContent(draftContent: string, seed: string): string {
    const draft = draftContent || ''
    if (!seed) {
      return draft
    }
    if (this.containsInitialSeed(draft, seed)) {
      return draft
    }
    if (draft.trim().length === 0) {
      return seed
    }
    return `${draft.replace(/\s+$/g, '')}\n\n${seed}`
  }

  private containsInitialSeed(draftContent: string, seed: string): boolean {
    const target = seed.trim()
    if (!target) {
      return false
    }
    const parts = (draftContent || '').split(/\s+/)
    for (let i = 0; i < parts.length; i++) {
      if (parts[i] === target) {
        return true
      }
    }
    return false
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
    if (this.isSaving || this.topicId <= 0) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.saveReplyDraft(context, this.topicId, this.content)
      .then(() => {
        this.savedAt = Math.floor(Date.now() / 1000)
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
    AlertDialog.show({
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
    DraftSettings.clearReplyDraft(context, this.topicId)
      .then(() => {
        promptAction.openToast({ message: '已清空' }).catch((_error: Error) => { })
      })
      .catch((_error: Error) => {
        promptAction.openToast({ message: '清空失败' }).catch((_error2: Error) => { })
      })
  }

  private canSubmit(): boolean {
    if (this.isSubmitting || this.isSubmitDialogShown || this.topicId <= 0) {
      return false
    }
    if (this.content.trim().length === 0) {
      return false
    }
    return !!CookieJarSettings.getCurrentCookie()
  }

  private confirmSubmit(): void {
    if (this.isSubmitting || this.isSubmitDialogShown) {
      return
    }
    const cleanContent = this.content.trim()
    if (cleanContent.length === 0) {
      promptAction.openToast({ message: '回复内容不能为空' }).catch((_error: Error) => { })
      return
    }
    if (!CookieJarSettings.getCurrentCookie()) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => { })
      return
    }
    const title = (this.topicTitle || '').trim()
    this.submitContentSnapshot = cleanContent
    this.isSubmitDialogShown = true
    this.persistDraft()
    const target = title ? `《${title}》` : '当前主题'
    const message = `确定向${target}提交回复吗？\n\n` +
      'V2EX 回复通常至少消耗 5 铜币，提交后会修改你的账号状态。'
    AlertDialog.show({
      title: '提交回复',
      message: message,
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
        DraftSettings.clearReplyDraft(context, this.topicId).catch((_error: Error) => { })
        promptAction.openToast({ message: '已提交' }).catch((_error: Error) => { })
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
