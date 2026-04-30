import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  V2exNode, NodeTopicListParams, ThemeConstants, StorageKeys
} from 'shared'

@Component
export struct DiscoverPage {
  @Consume(StorageKeys.NAV_PATH_STACK) ns: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM

  aboutToAppear(): void { this.vm.loadAllNodes() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
      } else {
        Scroll() {
          GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: ThemeConstants.SPACE_SM, y: ThemeConstants.SPACE_SM } }) {
            LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
              GridCol({ span: { sm: 1, md: 2, lg: 2 } }) {
                Column() {
                  Text(node.title).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_primary')).maxLines(1)
                  Text(`${node.topics} 主题`).fontSize(ThemeConstants.FONT_SIZE_TINY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
                }
                  .alignItems(HorizontalAlign.Center).padding(ThemeConstants.SPACE_MD).width('100%').borderRadius(ThemeConstants.RADIUS_MD)
                  .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
                  .onClick(() => {
                    let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }
                    this.ns.pushPathByName('NodeTopicList', p as Object)
                  })
              }
            }, (node: V2exNode) => node.id.toString())
          }
            .padding({
              left: this.GAP, right: this.GAP,
              top: this.topH + this.TBH,
              bottom: this.bottomH + this.FLOAT_H
            })
            .width('100%')
        }
          .scrollBar(BarState.Off)
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
