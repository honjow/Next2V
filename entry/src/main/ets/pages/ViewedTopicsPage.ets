import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  CollectionSettings,
  AppStrings,
  connectNavStack,
  EmptyState,
  LocalTopicCard,
  PullRefreshListScaffold,
  type TopicDetailParams,
  type ViewedTopic
} from 'shared'
import { LocalRecordDeleteSwipeAction } from '../components/LocalRecordSwipeActions'

@ComponentV2
export struct ViewedTopicsPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder);
  // used purely as a method target (pushPathByName), so no V2 reactivity is needed.
  private stack: NavPathStack = connectNavStack().stack
  @Local private topics: ViewedTopic[] = []

  aboutToAppear(): void {
    this.loadTopics()
  }

  build() {
    Column() {
      PullRefreshListScaffold({ onRefresh: () => this.loadTopics() }) {
        if (this.topics.length === 0) {
          ListItem() {
            EmptyState({ message: AppStrings.text($r('app.string.empty_no_recent_views'), 'No recent views yet'), stateHeight: 220 })
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
                metaLabel: AppStrings.text($r('app.string.viewed_on_label'), 'Viewed on'),
                metaTimestamp: item.viewedAt,
                onUserClick: () => { this.openTopic(item.id) },
                onNodeClick: () => { this.openTopic(item.id) }
              })
                .onClick(() => { this.openTopic(item.id) })
            }
            .onClick(() => { this.openTopic(item.id) })
            .swipeAction({ end: this.DeleteSwipeEnd(item.id) })
          }, (item: ViewedTopic) => `viewed-${item.id}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  DeleteSwipeEnd(topicId: number) {
    LocalRecordDeleteSwipeAction({ onDelete: () => { this.deleteTopic(topicId) } })
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

  // Optimistic single-row remove: drop it immediately for instant feedback, then let
  // removeViewedTopic's authoritative reload replace the list; on failure reload to restore and toast.
  private deleteTopic(topicId: number): void {
    if (topicId <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.topics = this.topics.filter((t: ViewedTopic) => t.id !== topicId)
    CollectionSettings.removeViewedTopic(context, topicId)
      .then((items: ViewedTopic[]) => {
        this.topics = items
      })
      .catch((error: Error) => {
        console.error('remove viewed topic failed: ' + error.message)
        this.loadTopics()
        promptAction
          .openToast({ message: AppStrings.text($r('app.string.common_delete_failed'), 'Delete failed') })
          .catch((_e: Error) => {})
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
