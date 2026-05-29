import { AppStrings } from 'shared'
import { common } from '@kit.AbilityKit'
import {
  ApiService,
  CollectionSettings,
  ConciseListRow,
  DateUtils,
  EmptyState,
  GroupedListSection,
  NodeIndexRepository,
  SecondaryListScaffold,
  type NodeTopicListParams,
  type SavedNode,
  type V2exNode
} from 'shared'

// State Management V2 row model. Identity is the node `name`; the display
// fields are @Trace so that when node icons/titles resolve asynchronously the
// existing row refreshes in place. This is what lets the ForEach key stay a
// pure identity key instead of embedding the avatar URL to force a rebuild.
@ObservedV2
class SavedNodeRow {
  name: string = ''
  @Trace title: string = ''
  @Trace topics: number = 0
  @Trace icon: string = ''
  @Trace savedAt: number = 0

  constructor(name: string) {
    this.name = name
  }

  applyNode(node: SavedNode): void {
    this.title = node.title || ''
    this.topics = node.topics || 0
    this.icon = node.avatarNormal || node.avatarMini || node.avatarLarge || ''
    this.savedAt = node.savedAt || 0
  }
}

// V2 component boundary: reading the @Trace fields here is what subscribes the
// row to in-place field updates, so a same-name row re-renders without the
// ForEach having to tear it down and rebuild it.
@ComponentV2
struct SavedNodeRowView {
  @Param row: SavedNodeRow = new SavedNodeRow('')
  @Event onOpen: () => void = () => {}

  build() {
    GroupedListSection() {
      ConciseListRow({
        title: this.rowTitle(),
        subtitle: this.rowSubtitle(),
        leadingImageUrl: this.row.icon,
        action: () => { this.onOpen() }
      })
    }
  }

  private rowTitle(): string {
    return CollectionSettings.cleanNodeTitle(this.row.title || this.row.name, this.row.topics) || this.row.name
  }

  private rowSubtitle(): string {
    const parts: string[] = [this.row.name]
    if (this.row.topics > 0) {
      parts.push(AppStrings.format(AppStrings.text(AppStrings.R_NODE_TOPICS_COUNT, '{0} topics'), [String(this.row.topics)]))
    }
    parts.push(AppStrings.format(AppStrings.text($r('app.string.saved_locally_on_format'), 'Saved locally on {0}'), [DateUtils.toDateString(this.row.savedAt)]))
    return parts.join(' · ')
  }
}

@Component
export struct SavedNodesPage {
  @Consume('ns') stack: NavPathStack
  @State private nodes: SavedNodeRow[] = []
  private api: ApiService = new ApiService()
  // Exactly one observed row object per node name, reused across reloads and
  // async enrichment so same-name rows mutate in place instead of relying on
  // ForEach key churn.
  private nodeRowsByName: Map<string, SavedNodeRow> = new Map()

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
        ForEach(this.nodes, (item: SavedNodeRow) => {
          ListItem() {
            SavedNodeRowView({
              row: item,
              onOpen: () => { this.openNode(item) }
            })
          }
          .onClick(() => { this.openNode(item) })
        }, (item: SavedNodeRow) => `saved-node-${item.name}`)
      }
    }
  }

  private loadNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedNodes(context)
      .then((items: SavedNode[]) => {
        this.applyNodes(items)
        this.enrichMissingNodeIcons(items)
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }

  private openNode(item: SavedNodeRow): void {
    const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: this.nodeTitle(item) }
    this.stack.pushPathByName('NodeTopicList', p as Object)
  }

  private nodeTitle(item: SavedNodeRow): string {
    return CollectionSettings.cleanNodeTitle(item.title || item.name, item.topics) || item.name
  }

  private enrichMissingNodeIcons(items: SavedNode[]): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (items.every((item: SavedNode) => this.nodeIcon(item))) {
      return
    }
    NodeIndexRepository.getNodes(this.api)
      .then((result) => {
        const allNodes: V2exNode[] = result.nodes
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
        this.applyNodes(enriched)
        return CollectionSettings.updateSavedNodesMetadata(context, enriched)
      })
      .then((next: SavedNode[]) => {
        this.applyNodes(next)
      })
      .catch((error: Error) => {
        console.error('enrich saved node icons failed: ' + error.message)
      })
  }

  private nodeIcon(item: SavedNode): string {
    return item.avatarNormal || item.avatarMini || item.avatarLarge || ''
  }

  // Reuse/prune stable row objects by name, then update each row's @Trace
  // fields in place. Reassigning this.nodes only re-keys membership/order;
  // unchanged-name rows keep their identity and refresh via @Trace.
  private applyNodes(items: SavedNode[]): void {
    const rows = this.ensureNodeRowsForNames(items.map((item: SavedNode) => item.name))
    for (let index = 0; index < items.length; index++) {
      rows[index].applyNode(items[index])
    }
    this.nodes = rows
  }

  private ensureNodeRowsForNames(names: string[]): SavedNodeRow[] {
    const validNames: Set<string> = new Set(names)
    const byName: Map<string, SavedNodeRow> = this.nodeRowsByName
    for (const existingName of Array.from(byName.keys())) {
      if (!validNames.has(existingName)) {
        byName.delete(existingName)
      }
    }
    return names.map((name: string): SavedNodeRow => this.nodeRowForName(name))
  }

  private nodeRowForName(name: string): SavedNodeRow {
    const existing = this.nodeRowsByName.get(name)
    if (existing) {
      return existing
    }
    const row = new SavedNodeRow(name)
    this.nodeRowsByName.set(name, row)
    return row
  }
}
