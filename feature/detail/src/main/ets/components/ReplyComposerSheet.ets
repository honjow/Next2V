import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ReplyComposerCoordinator,
  type ReplyComposerEditResult,
} from '../model/ReplyComposerCoordinator'
import {
  ApiService,
  CookieJarSettings,
  DateUtils,
  DraftSettings,
  MarkdownContent,
  MarkdownToolbar,
  AppModalScaffold,
  StorageKeys,
  ThemeConstants
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
      title: '写回复',
      compact: true,
      includeKeyboardPadding: true,
      closeAction: () => {
        this.close()
      }
    }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (this.topicTitle) {
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
              onBold: () => { this.insertInlineMarkdown('**', '**', '文字') },
              onItalic: () => { this.insertInlineMarkdown('*', '*', '文字') },
              onCode: () => { this.insertInlineMarkdown('`', '`', '代码') },
              onQuote: () => { this.insertLinePrefix('> ') },
              onList: () => { this.insertLinePrefix('- ') },
              onLink: () => { this.insertInlineMarkdown('[', '](https://)', '文字', '[文字](https://'.length) },
              onImage: () => { this.insertImageLinkTemplate() },
              onClear: () => { this.confirmClearDraft() }
            })
              .layoutWeight(1)

            Button(this.isSubmitting ? '提交中' : '提交', { type: ButtonType.Capsule })
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
              Text('暂无内容')
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
            TextArea({ placeholder: '写回复（自动保存草稿）', text: this.content, controller: this.contentController })
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
            Text(`已保存于 ${DateUtils.toDateString(this.savedAt)}`)
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        .width('100%')
      }
    }
  }

  private loadDraft(): void {
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
        const seed = ReplyComposerCoordinator.normalizeInitialContent(this.initialContent)
        const draftContent = draft ? (draft.content || '') : ''
        this.content = ReplyComposerCoordinator.mergeInitialContent(draftContent, seed)
        this.savedAt = draft ? (draft.updatedAt || 0) : 0
        this.contentSelectionStart = this.content.length
        this.contentSelectionEnd = this.content.length
        if (seed && this.content !== draftContent) {
          this.scheduleSaveDraft()
        }
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '读取草稿失败'
      })
  }

  private insertImageLinkTemplate(): void {
    this.insertInlineMarkdown('![', '](https://)', '图片', '![图片](https://'.length)
  }

  private insertInlineMarkdown(prefix: string, suffix: string, placeholder: string, caretOffset: number = -1): void {
    const result = ReplyComposerCoordinator.insertInlineMarkdown(
      this.content,
      this.contentSelectionStart,
      this.contentSelectionEnd,
      prefix,
      suffix,
      placeholder,
      caretOffset,
    )
    this.applyEditResult(result)
    this.isPreview = false
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(result.caret)
    }, 0)
  }

  private insertLinePrefix(prefix: string): void {
    const result = ReplyComposerCoordinator.insertLinePrefix(
      this.content,
      this.contentSelectionStart,
      this.contentSelectionEnd,
      prefix,
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
    if (this.topicId <= 0 || this.hasSubmitted) {
      return
    }
    this.clearSaveTimer()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.saveReplyDraft(context, this.topicId, this.content)
      .then(() => {
        this.savedAt = Math.floor(Date.now() / 1000)
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存草稿失败'
      })
  }

  private confirmClearDraft(): void {
    AlertDialog.show({
      title: '清空草稿',
      message: '确定清空当前回复草稿吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '清空',
        action: () => {
          this.content = ''
          this.savedAt = 0
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext
          DraftSettings.clearReplyDraft(context, this.topicId).catch((_error: Error) => { })
        }
      }
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

  private composerBodyHeight(): number {
    return ReplyComposerCoordinator.composerBodyHeight(this.keyboardH)
  }

  private confirmSubmit(): void {
    const cleanContent = this.content.trim()
    if (this.isSubmitting || this.isSubmitDialogShown || this.topicId <= 0) {
      return
    }
    if (!cleanContent) {
      this.errorMessage = '回复内容不能为空'
      promptAction.openToast({ message: '回复内容不能为空' }).catch((_error: Error) => { })
      return
    }
    if (!CookieJarSettings.getCurrentCookie()) {
      this.errorMessage = '请先登录'
      return
    }
    this.submitContentSnapshot = cleanContent
    this.isSubmitDialogShown = true
    this.persistDraft()
    AlertDialog.show({
      title: '提交回复',
      message: '确定提交这条回复吗？',
      primaryButton: { value: '取消', action: () => { this.isSubmitDialogShown = false } },
      secondaryButton: { value: '提交', action: () => { this.submitReply() } }
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
        DraftSettings.clearReplyDraft(context, this.topicId).catch((_error: Error) => { })
        promptAction.openToast({ message: '回复已提交' }).catch((_error: Error) => { })
        if (this.submittedAction) {
          this.submittedAction()
        }
        this.close()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '提交失败'
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
