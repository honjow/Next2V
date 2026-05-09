import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { NodeViewModel } from '../viewmodel/NodeViewModel'
import { DraftSettings, ThemeConstants, V2exNode, SecondaryListScaffold } from 'shared'

@Component
export struct NodePickerPage {
  @Consume('ns') stack: NavPathStack

  @State vm: NodeViewModel = new NodeViewModel()

  @State private selectedNodeName: string = ''
  @State private isSaving: boolean = false
  @State private errorMessage: string = ''

  aboutToAppear(): void {
    this.loadSelectedNode()
    this.vm.loadAllNodes()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
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
                  .onClick(() => { this.clearSelectedNode() })
              }
              .width('100%')
            }

            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
                .width('100%')
            }

            TextInput({ placeholder: '搜索节点', text: this.vm.keyword })
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .height(44)
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .onChange((value: string) => {
                this.vm.setNodeFilter(value)
              })
          }
          .width('100%')
        }

        if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            Column() {
              LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
              Text('加载中...')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: ThemeConstants.SPACE_SM })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
          }
        } else if (this.vm.errorMessage && this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            Column() {
              Text(this.vm.errorMessage)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
              Button('重试', { type: ButtonType.Capsule })
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .margin({ top: ThemeConstants.SPACE_LG })
                .onClick(() => { this.vm.loadAllNodes() })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
          }
        } else if (this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            Column() {
              Text('没有匹配的节点')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL })
          }
        } else {
          LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
            ListItem() {
              this.NodeRow(node)
            }
          }, (node: V2exNode) => node.id.toString())
        }
      }
    }
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
