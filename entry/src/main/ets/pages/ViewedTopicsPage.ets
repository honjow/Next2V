import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  ConciseListRow,
  EmptyState,
  GroupedListSection,
  SecondaryListScaffold,
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
    SecondaryListScaffold() {
      if (this.topics.length === 0) {
        ListItem() {
          EmptyState({ message: '还没有最近浏览记录', stateHeight: 220 })
        }
      } else {
        ForEach(this.topics, (item: ViewedTopic) => {
          ListItem() {
            GroupedListSection() {
              ConciseListRow({
                title: item.title,
                subtitle: this.topicSubtitle(item)
              })
            }
          }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.stack.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: ViewedTopic) => `viewed-${item.id}`)
      }
    }
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

  private topicSubtitle(item: ViewedTopic): string {
    const node = item.nodeTitle || item.nodeName
    const author = item.username || ''
    if (node && author) {
      return `${node} · ${author}`
    }
    return node || author
  }
}
