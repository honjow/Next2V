import { V2exNode, ThemeConstants, ApiService, NodeTopicListParams } from 'shared'

@Component
export struct DiscoverPage {
  @Consume('ns') ns: NavPathStack
  @State nodes: V2exNode[] = []
  @State loading: boolean = false
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = 56
  private readonly FLOAT_H: number = 76
  private readonly GAP: number = 8
  private api: ApiService = new ApiService()

  aboutToAppear(): void { this.loadNodes() }

  async loadNodes(): Promise<void> {
    this.loading = true
    try { this.nodes = await this.api.getAllNodes() } catch (e) {}
    this.loading = false
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(32).height(32)
      } else {
        Scroll() {
          GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: 8, y: 8 } }) {
            ForEach(this.nodes, (node: V2exNode) => {
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
            })
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
