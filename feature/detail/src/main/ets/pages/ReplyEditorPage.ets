import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { DateUtils, DraftSettings, MarkdownContent, StorageKeys, ThemeConstants } from 'shared'

@Component
export struct ReplyEditorPage {
  @Prop topicId: number = 0
  @Prop topicTitle: string = ''
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) writeEnabled: boolean = false

  @State private content: string = ''
  @State private isPreview: boolean = false
  @State private errorMessage: string = ''
  @State private savedAt: number = 0

  private saveTimerId: number = 0
  private isSaving: boolean = false

  aboutToAppear(): void {
    this.content = ''
    this.isPreview = false
    this.errorMessage = ''
    this.savedAt = 0

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadReplyDraft(context, this.topicId)
      .then((draft) => {
        if (draft) {
          this.content = draft.content || ''
          this.savedAt = draft.updatedAt || 0
        }
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '读取草稿失败'
      })
  }

  aboutToDisappear(): void {
    this.clearSaveTimer()
    this.persistDraft()
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('回复草稿')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      if (this.topicTitle) {
        Text(this.topicTitle)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Row({ space: ThemeConstants.SPACE_SM }) {
        Text('编辑')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(!this.isPreview ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 6, bottom: 6 })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => { this.isPreview = false })
        Text('预览')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(this.isPreview ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 6, bottom: 6 })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => { this.isPreview = true })
        Blank()
        Text('清空')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 6, bottom: 6 })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => { this.confirmClearDraft() })
      }
      .width('100%')

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      if (!this.isPreview) {
        TextArea({ placeholder: '写回复（仅保存草稿，不会提交）', text: this.content })
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .height(260)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .onChange((value: string) => {
            this.content = value
            this.scheduleSaveDraft()
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
          .height(260)
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

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('返回')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .onClick(() => { this.stack.pop() })
        Button(this.writeEnabled ? '提交（未开放）' : '提交（需开启写入开关）')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .enabled(false)
          .onClick(() => { })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
}
