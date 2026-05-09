import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  EmptyState,
  LocalTopicCard,
  PullRefreshListScaffold,
  type SavedTopic,
  type TopicDetailParams
} from 'shared'

@Component
export struct SavedTopicsPage {
  @Consume('ns') stack: NavPathStack
  @State private topics: SavedTopic[] = []

  aboutToAppear(): void {
    this.loadTopics()
  }

  build() {
    Column() {
      if (this.topics.length === 0) {
        Column() {
          EmptyState({ message: '还没有稍后读主题' })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else {
        PullRefreshListScaffold({ onRefresh: () => this.loadTopics() }) {
          ForEach(this.topics, (item: SavedTopic) => {
            ListItem() {
              LocalTopicCard({
                topicId: item.id,
                title: item.title,
                nodeName: item.nodeName,
                nodeTitle: item.nodeTitle,
                username: item.username,
                avatar: item.avatar || '',
                created: item.created,
                replyCount: this.replyCount(item),
                hasReplyCount: this.hasKnownReplyCount(item),
                metaLabel: '保存于',
                metaTimestamp: item.savedAt,
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
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private loadTopics(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    return CollectionSettings.loadSavedTopics(context)
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

  private hasKnownReplyCount(item: SavedTopic): boolean {
    return typeof item.replies === 'number' && item.replies >= 0
  }

  private replyCount(item: SavedTopic): number {
    return this.hasKnownReplyCount(item) ? item.replies as number : 0
  }
}
