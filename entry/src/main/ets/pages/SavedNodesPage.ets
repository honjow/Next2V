import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  DateUtils,
  EmptyState,
  SecondaryListScaffold,
  ThemeConstants,
  type NodeTopicListParams,
  type SavedNode
} from 'shared'

@Component
export struct SavedNodesPage {
  @Consume('ns') stack: NavPathStack
  @State private nodes: SavedNode[] = []

  aboutToAppear(): void {
    this.loadNodes()
  }

  build() {
    SecondaryListScaffold() {
      if (this.nodes.length === 0) {
        ListItem() {
          EmptyState({ message: '还没有关注节点', stateHeight: 220 })
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
      } else {
        ForEach(this.nodes, (item: SavedNode) => {
          ListItem() {
            SavedNodeRow({ item: item })
          }
          .onClick(() => {
            let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
            this.stack.pushPathByName('NodeTopicList', p as Object)
          })
        }, (item: SavedNode) => `node-${item.name}`)
      }
    }
  }

  private loadNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedNodes(context)
      .then((items: SavedNode[]) => {
        this.nodes = items
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }
}

@Component
struct SavedNodeRow {
  @Prop item: SavedNode

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.item.title || this.item.name)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`${this.item.name} · ${this.item.topics} 个主题 · 关注于 ${DateUtils.toDateString(this.item.savedAt)}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
