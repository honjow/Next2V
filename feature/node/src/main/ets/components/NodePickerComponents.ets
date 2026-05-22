import { ThemeConstants, V2exNode } from 'shared'

function defaultNode(): V2exNode {
  return {
    id: 0,
    name: '',
    title: '',
    title_alternative: '',
    url: '',
    topics: 0,
    avatar_mini: '',
    avatar_normal: '',
    avatar_large: ''
  }
}

@Component
export struct NodePickerHeader {
  @Prop selectedNodeName: string = ''
  @Prop isSaving: boolean = false
  @Prop errorMessage: string = ''
  @Prop keyword: string = ''
  clearAction?: () => void
  keywordChangeAction?: (value: string) => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('点击节点后会自动填入发帖草稿。')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')

      if (this.selectedNodeName) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(`当前：${this.selectedNodeName}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Button('清空', { type: ButtonType.Capsule })
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .enabled(!this.isSaving)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => {
              if (this.clearAction) {
                this.clearAction()
              }
            })
        }
        .width('100%')
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }

      TextInput({ placeholder: '搜索节点', text: this.keyword })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .onChange((value: string) => {
          if (this.keywordChangeAction) {
            this.keywordChangeAction(value)
          }
        })
    }
    .width('100%')
  }
}

@Component
export struct NodePickerLoadingState {
  build() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
      Text('加载中...')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_SM })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
  }
}

@Component
export struct NodePickerErrorState {
  @Prop message: string = ''
  retryAction?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试', { type: ButtonType.Capsule })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          if (this.retryAction) {
            this.retryAction()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
  }
}

@Component
export struct NodePickerEmptyState {
  build() {
    Column() {
      Text($r('app.string.search_no_nodes'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
  }
}

@Component
export struct NodePickerRow {
  @Prop node: V2exNode = defaultNode()
  @Prop selectedNodeName: string = ''
  selectAction?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.node.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.node.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: ThemeConstants.SPACE_XS }) {
        if (this.selectedNodeName === this.node.name) {
          Text($r('app.string.common_selected'))
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
        }
        Text(`${this.node.topics} 主题`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => {
      if (this.selectAction) {
        this.selectAction()
      }
    })
  }
}
