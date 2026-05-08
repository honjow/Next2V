import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  EmptyState,
  SecondaryListScaffold,
  TopicCard,
  type TopicDetailParams,
  type V2exMember,
  type V2exNode,
  type V2exTopic,
  type ViewedTopic
} from 'shared'

@Component
export struct ViewedTopicsPage {
  @Consume('ns') stack: NavPathStack
  @State private topics: ViewedTopic[] = []

  aboutToAppear(): void {
    this.loadTopics()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        if (this.topics.length === 0) {
          ListItem() {
            EmptyState({ message: '还没有最近浏览记录', stateHeight: 220 })
          }
        } else {
          ForEach(this.topics, (item: ViewedTopic) => {
            ListItem() {
              TopicCard({
                item: this.toTopic(item),
                metaLabel: '浏览于',
                metaTimestamp: item.viewedAt,
                hideLocalSnapshotReplyCount: !this.hasKnownReplyCount(item),
                onUserClick: () => { this.openTopic(item.id) },
                onNodeClick: () => { this.openTopic(item.id) }
              })
                .onClick(() => { this.openTopic(item.id) })
            }
            .onClick(() => { this.openTopic(item.id) })
          }, (item: ViewedTopic) => `viewed-${item.id}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private loadTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadViewedTopics(context)
      .then((items: ViewedTopic[]) => {
        this.topics = items
      })
      .catch((error: Error) => {
        console.error('load viewed topics failed: ' + error.message)
      })
  }

  private openTopic(topicId: number): void {
    if (topicId <= 0) {
      return
    }
    let p: TopicDetailParams = { topicId: topicId }
    this.stack.pushPathByName('TopicDetail', p as Object)
  }

  private toTopic(item: ViewedTopic): V2exTopic {
    const member: V2exMember = {
      id: 0,
      username: item.username || '',
      tagline: '',
      avatar_mini: item.avatar || '',
      avatar_normal: item.avatar || '',
      avatar_large: item.avatar || ''
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
      created: item.viewedAt,
      last_modified: item.viewedAt,
      last_touched: item.viewedAt
    }
  }

  private hasKnownReplyCount(item: ViewedTopic): boolean {
    return typeof item.replies === 'number' && item.replies >= 0
  }

  private replyCount(item: ViewedTopic): number {
    return this.hasKnownReplyCount(item) ? item.replies as number : 0
  }
}
