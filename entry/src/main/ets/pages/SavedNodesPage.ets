import { AppStrings } from 'shared'
import { common } from '@kit.AbilityKit'
import {
  ApiService,
  CollectionSettings,
  ConciseListRow,
  DateUtils,
  EmptyState,
  GroupedListSection,
  SecondaryListScaffold,
  type NodeTopicListParams,
  type SavedNode,
  type V2exNode
} from 'shared'

@Component
export struct SavedNodesPage {
  @Consume('ns') stack: NavPathStack
  @State private nodes: SavedNode[] = []
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.loadNodes()
  }

  build() {
    SecondaryListScaffold() {
      if (this.nodes.length === 0) {
        ListItem() {
          EmptyState({ message: AppStrings.text($r('app.string.empty_no_local_followed_nodes'), 'No local followed nodes yet'), stateHeight: 220 })
        }
      } else {
        ForEach(this.nodes, (item: SavedNode) => {
          ListItem() {
            GroupedListSection() {
              ConciseListRow({
                title: this.nodeTitle(item),
                subtitle: this.nodeSubtitle(item),
                leadingImageUrl: this.nodeIcon(item),
                action: () => { this.openNode(item) }
              })
            }
          }
          .onClick(() => { this.openNode(item) })
        }, (item: SavedNode) => `node-${item.name}-${this.nodeIcon(item)}`)
      }
    }
  }

  private loadNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedNodes(context)
      .then((items: SavedNode[]) => {
        this.nodes = items
        this.enrichMissingNodeIcons(items)
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }

  private nodeSubtitle(item: SavedNode): string {
    const parts: string[] = [item.name]
    if (item.topics > 0) {
      parts.push(AppStrings.format(AppStrings.text(AppStrings.R_NODE_TOPICS_COUNT, '{0} topics'), [String(item.topics)]))
    }
    parts.push(AppStrings.format(AppStrings.text($r('app.string.saved_locally_on_format'), 'Saved locally on {0}'), [DateUtils.toDateString(item.savedAt)]))
    return parts.join(' · ')
  }

  private nodeTitle(item: SavedNode): string {
    return CollectionSettings.cleanNodeTitle(item.title || item.name, item.topics) || item.name
  }

  private nodeIcon(item: SavedNode): string {
    return item.avatarNormal || item.avatarMini || item.avatarLarge || ''
  }

  private openNode(item: SavedNode): void {
    const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: this.nodeTitle(item) }
    this.stack.pushPathByName('NodeTopicList', p as Object)
  }

  private enrichMissingNodeIcons(items: SavedNode[]): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (items.every((item: SavedNode) => this.nodeIcon(item))) {
      return
    }
    this.api.getAllNodes()
      .then((allNodes: V2exNode[]) => {
        const nodeByName: Record<string, V2exNode> = {}
        allNodes.forEach((node: V2exNode) => {
          nodeByName[node.name] = node
        })
        const enriched = items.map((item: SavedNode) => {
          const detail = nodeByName[item.name]
          if (!detail) {
            return item
          }
          return {
            name: item.name,
            title: detail.title || item.title,
            topics: detail.topics || item.topics,
            avatarMini: item.avatarMini || detail.avatar_mini,
            avatarNormal: item.avatarNormal || detail.avatar_normal,
            avatarLarge: item.avatarLarge || detail.avatar_large,
            savedAt: item.savedAt
          } as SavedNode
        })
        this.nodes = enriched
        return CollectionSettings.updateSavedNodesMetadata(context, enriched)
      })
      .then((next: SavedNode[]) => {
        this.nodes = next
      })
      .catch((error: Error) => {
        console.error('enrich saved node icons failed: ' + error.message)
      })
  }
}
