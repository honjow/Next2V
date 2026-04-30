import { V2exNode, ThemeConstants, NodeTopicListParams, BreakPointType } from 'shared'
import { NodeViewModel } from '../viewmodel/NodeViewModel'

@Component
export struct NodeListPage {
  @State viewModel: NodeViewModel = new NodeViewModel()
  @Consume('pageStack') pageStack: NavPathStack
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm'

  aboutToAppear(): void {
    this.viewModel.loadAllNodes()
  }

  build() {
    NavDestination() {
      if (this.viewModel.isLoading) {
        Column() {
          LoadingProgress()
            .width(32).height(32)
          Text('加载节点...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: ThemeConstants.SPACE_MD })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%').height('100%')
      } else {
        Scroll() {
          GridRow({
            columns: { sm: 2, md: 4, lg: 6 },
            gutter: { x: 8, y: 8 }
          }) {
            ForEach(this.viewModel.allNodes, (node: V2exNode) => {
              GridCol({
                span: new BreakPointType({ sm: 1, md: 2, lg: 2 }).getValue(this.currentBreakpoint)
              }) {
                Column() {
                  Text(node.title)
                    .fontSize(ThemeConstants.FONT_SIZE_BODY)
                    .fontColor($r('sys.color.font_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(node.name)
                    .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                    .fontColor($r('sys.color.font_secondary'))
                    .margin({ top: 2 })
                  Text(`${node.topics} 主题`)
                    .fontSize(10)
                    .fontColor($r('sys.color.font_secondary'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Center)
                .padding(ThemeConstants.SPACE_MD)
                .width('100%')
                .borderRadius(ThemeConstants.RADIUS_MD)
                .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
                .onClick(() => {
                  let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }
                  this.pageStack.pushPathByName('NodeTopicList', p)
                })
              }
            })
          }
          .padding(ThemeConstants.SPACE_MD)
          .width('100%')
        }
        .width('100%').height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .hideTitleBar(false)
    .title('节点')
  }
}
