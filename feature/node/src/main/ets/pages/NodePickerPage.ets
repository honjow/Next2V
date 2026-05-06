import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { NodeViewModel } from '../viewmodel/NodeViewModel'
import { DraftSettings, StorageKeys, ThemeConstants, V2exNode } from 'shared'

@Component
export struct NodePickerPage {
  @Consume('ns') stack: NavPathStack

  @State vm: NodeViewModel = new NodeViewModel()

  @State private selectedNodeName: string = ''
  @State private isSaving: boolean = false
  @State private errorMessage: string = ''
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  aboutToAppear(): void {
    this.loadSelectedNode()
    this.vm.loadAllNodes()
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('选择节点')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      Text('点击节点后会自动填入发帖草稿。')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))

      if (this.selectedNodeName) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(`当前：${this.selectedNodeName}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('清空')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .onClick(() => { this.clearSelectedNode() })
        }
        .width('100%')
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      TextInput({ placeholder: '搜索节点', text: this.vm.keyword })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .onChange((value: string) => {
          this.vm.setNodeFilter(value)
        })

      if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
          Text('加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: ThemeConstants.SPACE_SM })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else if (this.vm.errorMessage && this.vm.nodeDataSource.totalCount() === 0) {
        Column() {
          Text(this.vm.errorMessage)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
          Button('重试')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .margin({ top: ThemeConstants.SPACE_LG })
            .onClick(() => { this.vm.loadAllNodes() })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else if (this.vm.nodeDataSource.totalCount() === 0) {
        Column() {
          Text('没有匹配的节点')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: ThemeConstants.SPACE_XS }) {
          LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
            ListItem() {
              this.NodeRow(node)
            }
          }, (node: V2exNode) => node.id.toString())
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
      }

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('返回')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .enabled(!this.isSaving)
          .onClick(() => { this.stack.pop() })
      }
      .width('100%')
    }
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
      bottom: this.bottomH + ThemeConstants.SPACE_MD
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder NodeRow(node: V2exNode) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(node.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(node.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: ThemeConstants.SPACE_XS }) {
        if (this.selectedNodeName === node.name) {
          Text('已选')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
        }
        Text(`${node.topics} 主题`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => { this.selectNode(node.name) })
  }

  private loadSelectedNode(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        this.selectedNodeName = draft?.nodeName || ''
      })
      .catch((_error: Error) => {
        this.selectedNodeName = ''
      })
  }

  private selectNode(nodeName: string): void {
    const clean = nodeName.trim()
    if (!clean || this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        return DraftSettings.saveTopicDraft(context, clean, draft?.title || '', draft?.content || '')
      })
      .then(() => {
        this.selectedNodeName = clean
        promptAction.openToast({ message: `已选择节点：${clean}` }).catch((_error: Error) => { })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }

  private clearSelectedNode(): void {
    if (this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        if (!draft) {
          return DraftSettings.saveTopicDraft(context, '', '', '')
        }
        return DraftSettings.saveTopicDraft(context, '', draft.title || '', draft.content || '')
      })
      .then(() => {
        this.selectedNodeName = ''
        promptAction.openToast({ message: '已清空节点' }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '清空失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }
}
