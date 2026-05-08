import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  ConciseListRow,
  DateUtils,
  EmptyState,
  GroupedListSection,
  SecondaryListScaffold,
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
          EmptyState({ message: '还没有本地关注节点', stateHeight: 220 })
        }
      } else {
        ForEach(this.nodes, (item: SavedNode) => {
          ListItem() {
            GroupedListSection() {
              ConciseListRow({
                title: item.title || item.name,
                subtitle: this.nodeSubtitle(item)
              })
            }
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

  private nodeSubtitle(item: SavedNode): string {
    const parts: string[] = [item.name]
    if (item.topics > 0) {
      parts.push(`${item.topics} 个主题`)
    }
    parts.push(`本地关注于 ${DateUtils.toDateString(item.savedAt)}`)
    return parts.join(' · ')
  }
}
