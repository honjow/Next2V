import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { ApiService, CookieJarSettings, DateUtils, DraftSettings, MarkdownContent, StorageKeys, ThemeConstants } from 'shared'

@Component
export struct TopicEditorPage {
  @Consume('ns') stack: NavPathStack

  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) writeEnabled: boolean = false
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  @State private nodeName: string = ''
  @State private title: string = ''
  @State private content: string = ''
  @State private isPreview: boolean = false
  @State private errorMessage: string = ''
  @State private savedAt: number = 0
  @State private isSubmitting: boolean = false
  @State private contentSelectionStart: number = 0
  @State private contentSelectionEnd: number = 0

  private contentController: TextAreaController = new TextAreaController()
  private saveTimerId: number = 0
  private isSaving: boolean = false
  private hasSubmitted: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.nodeName = ''
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
          this.title = draft.title || ''
          this.content = draft.content || ''
          this.savedAt = draft.updatedAt || 0
          this.contentSelectionStart = this.content.length
          this.contentSelectionEnd = this.content.length
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
    Scroll() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          TextInput({ placeholder: '节点（如 create）', text: this.nodeName })
            .height(44)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .borderRadius(ThemeConstants.RADIUS_MD)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.nodeName = value
              this.scheduleSaveDraft()
            })
          Button('选择')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(44)
            .type(ButtonType.Normal)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .enabled(!this.isSubmitting)
            .onClick(() => { this.stack.pushPathByName('NodePicker', null) })
        }
        .width('100%')

        TextInput({ placeholder: '标题', text: this.title })
          .height(44)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(ThemeConstants.RADIUS_MD)
          .onChange((value: string) => {
            this.title = value
            this.scheduleSaveDraft()
          })

        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          Button('编辑')
            .type(ButtonType.Normal)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(!this.isPreview ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .onClick(() => { this.isPreview = false })
          Button('预览')
            .type(ButtonType.Normal)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(this.isPreview ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .onClick(() => { this.isPreview = true })
          Button('图片')
            .type(ButtonType.Normal)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .onClick(() => { this.insertImageLinkTemplate() })
          Button('清空')
            .type(ButtonType.Normal)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .onClick(() => { this.confirmClearDraft() })
        }
        .width('100%')

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
        }

        if (!this.isPreview) {
          TextArea({ placeholder: '正文（Markdown）', text: this.content, controller: this.contentController })
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

        if (!this.writeEnabled) {
          Text('写入操作开关未开启，提交能力不会启用。')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }

        Button(this.writeEnabled ? (this.isSubmitting ? '提交中...' : '提交') : '提交（需开启写入开关）')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .width('100%')
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .enabled(this.canSubmit())
          .onClick(() => { this.confirmSubmit() })
      }
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
        bottom: this.bottomH + ThemeConstants.SPACE_XL
      })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private insertImageLinkTemplate(): void {
    const template = '![图片](https://)'
    const caretOffset = '![图片](https://'.length
    const contentLength = this.content.length
    const start = Math.min(Math.max(this.contentSelectionStart, 0), contentLength)
    const rawEnd = Math.min(Math.max(this.contentSelectionEnd, 0), contentLength)
    const end = rawEnd >= start ? rawEnd : start
    this.content = `${this.content.substring(0, start)}${template}${this.content.substring(end)}`
    const caret = start + caretOffset
    this.contentSelectionStart = caret
    this.contentSelectionEnd = caret
    this.isPreview = false
    this.scheduleSaveDraft()
    setTimeout(() => {
      this.contentController.caretPosition(caret)
    }, 0)
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
    DraftSettings.saveTopicDraft(context, this.nodeName, this.title, this.content)
      .then(() => {
        const now = Math.floor(Date.now() / 1000)
        this.savedAt = now
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
    if (!this.nodeName.trim() && !this.title.trim() && this.content.trim().length === 0) {
      this.clearDraft()
      return
    }
    AlertDialog.show({
      title: '清空草稿',
      message: '确定清空当前发帖草稿吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: () => { this.clearDraft() }
      }
    })
  }

  private clearDraft(): void {
    this.nodeName = ''
    this.title = ''
    this.content = ''
    this.contentSelectionStart = 0
    this.contentSelectionEnd = 0
    this.savedAt = 0
    this.errorMessage = ''
    this.clearSaveTimer()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.clearTopicDraft(context)
      .then(() => {
        promptAction.openToast({ message: '已清空' }).catch((_error: Error) => { })
      })
      .catch((_error: Error) => {
        promptAction.openToast({ message: '清空失败' }).catch((_error2: Error) => { })
      })
  }

  private canSubmit(): boolean {
    if (!this.writeEnabled || this.isSubmitting) {
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
    if (!this.writeEnabled) {
      promptAction.openToast({ message: '写入操作开关未开启' }).catch((_error: Error) => { })
      return
    }
    if (!this.nodeName.trim()) {
      promptAction.openToast({ message: '请选择节点' }).catch((_error: Error) => { })
      return
    }
    if (!this.title.trim()) {
      promptAction.openToast({ message: '请输入标题' }).catch((_error: Error) => { })
      return
    }
    if (this.content.trim().length === 0) {
      promptAction.openToast({ message: '请输入正文' }).catch((_error: Error) => { })
      return
    }
    if (!CookieJarSettings.getCurrentCookie()) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => { })
      return
    }
    const cleanNode = this.nodeName.trim()
    const cleanTitle = this.title.trim()
    const message = `确定在节点「${cleanNode}」发布主题《${cleanTitle}》吗？\n\n` +
      'V2EX 发帖通常至少消耗 20 铜币，提交后会修改你的账号状态。'
    AlertDialog.show({
      title: '确认发帖',
      message: message,
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: { value: '发布', action: () => { this.submit() } }
    })
  }

  private submit(): void {
    if (this.isSubmitting) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => { })
      return
    }
    this.isSubmitting = true
    this.errorMessage = ''
    this.api.createTopicWithCookie(cookie, this.nodeName, this.title, this.content)
      .then((topicId: number) => {
        this.hasSubmitted = true
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        DraftSettings.clearTopicDraft(context).catch((_error: Error) => { })
        promptAction.openToast({ message: topicId > 0 ? `已发帖：${topicId}` : '已发帖' }).catch((_error: Error) => { })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '提交失败'
        promptAction.openToast({ message: this.errorMessage }).catch((_error2: Error) => { })
      })
      .finally(() => {
        this.isSubmitting = false
      })
  }
}
