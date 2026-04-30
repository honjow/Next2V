import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  V2exNode, NodeTopicListParams
} from 'shared'

@Component
export struct DiscoverPage {
  @Consume('ns') ns: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = 56
  private readonly FLOAT_H: number = 76
  private readonly GAP: number = 8

  aboutToAppear(): void { this.vm.loadAllNodes() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
        LoadingProgress().width(32).height(32)
      } else {
        Scroll() {
          GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: 8, y: 8 } }) {
            LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
              GridCol({ span: { sm: 1, md: 2, lg: 2 } }) {
                Column() {
                  Text(node.title).fontSize(14).fontColor($r('sys.color.font_primary')).maxLines(1)
                  Text(`${node.topics} 主题`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ top: 4 })
                }
                  .alignItems(HorizontalAlign.Center).padding(12).width('100%').borderRadius(8)
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
