import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  EmptyState,
  SecondaryListScaffold,
  TopicCard,
  type SavedTopic,
  type TopicDetailParams,
  type V2exMember,
  type V2exNode,
  type V2exTopic
} from 'shared'

@Component
export struct SavedTopicsPage {
  @Consume('ns') stack: NavPathStack
  @State private topics: SavedTopic[] = []

  aboutToAppear(): void {
    this.loadTopics()
  }

  build() {
    SecondaryListScaffold() {
      if (this.topics.length === 0) {
        ListItem() {
          EmptyState({ message: '还没有稍后读主题', stateHeight: 220 })
        }
      } else {
        ForEach(this.topics, (item: SavedTopic) => {
          ListItem() {
            TopicCard({
              item: this.toTopic(item),
              metaLabel: '保存于',
              metaTimestamp: item.savedAt,
              hideLocalSnapshotReplyCount: !this.hasKnownReplyCount(item),
              onUserClick: () => { this.openTopic(item.id) },
              onNodeClick: () => { this.openTopic(item.id) }
            })
              .onClick(() => { this.openTopic(item.id) })
          }
          .onClick(() => { this.openTopic(item.id) })
        }, (item: SavedTopic) => `saved-${item.id}`)
      }
    }
  }

  private loadTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedTopics(context)
      .then((items: SavedTopic[]) => {
        this.topics = items
      })
      .catch((error: Error) => {
        console.error('load saved topics failed: ' + error.message)
      })
  }

  private openTopic(topicId: number): void {
    if (topicId <= 0) {
      return
    }
    let p: TopicDetailParams = { topicId: topicId }
    this.stack.pushPathByName('TopicDetail', p as Object)
  }

  private toTopic(item: SavedTopic): V2exTopic {
    const member: V2exMember = {
      id: 0,
      username: item.username || '',
      tagline: '',
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
    const node: V2exNode = {
      id: 0,
      name: item.nodeName || '',
      title: item.nodeTitle || item.nodeName || '',
      title_alternative: '',
      url: '',
      topics: 0,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
    return {
      id: item.id,
      title: item.title,
      url: '',
      content: '',
      content_rendered: '',
      replies: this.replyCount(item),
      member: member,
      node: node,
      created: item.created,
      last_modified: item.savedAt,
      last_touched: item.savedAt
    }
  }

  private hasKnownReplyCount(item: SavedTopic): boolean {
    return typeof item.replies === 'number' && item.replies >= 0
  }

  private replyCount(item: SavedTopic): number {
    return this.hasKnownReplyCount(item) ? item.replies as number : 0
  }
}
