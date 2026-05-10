import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  EmptyState,
  LocalTopicCard,
  PullRefreshListScaffold,
  type TopicDetailParams,
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
      PullRefreshListScaffold({ onRefresh: () => this.loadTopics() }) {
        if (this.topics.length === 0) {
          ListItem() {
            EmptyState({ message: '还没有最近浏览记录', stateHeight: 220 })
          }
        } else {
          ForEach(this.topics, (item: ViewedTopic) => {
            ListItem() {
              LocalTopicCard({
                topicId: item.id,
                title: item.title,
                nodeName: item.nodeName,
                nodeTitle: item.nodeTitle,
                username: item.username,
                avatar: item.avatar || '',
                memberPro: item.memberPro || 0,
                replyCount: this.replyCount(item),
                hasReplyCount: this.hasKnownReplyCount(item),
                metaLabel: '浏览于',
                metaTimestamp: item.viewedAt,
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

  private loadTopics(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    return CollectionSettings.loadViewedTopics(context)
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

  private hasKnownReplyCount(item: ViewedTopic): boolean {
    return typeof item.replies === 'number' && item.replies >= 0
  }

  private replyCount(item: ViewedTopic): number {
    return this.hasKnownReplyCount(item) ? item.replies as number : 0
  }
}
