import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  DateUtils,
  ConciseListRow,
  EmptyState,
  GroupedListSection,
  SecondaryListScaffold,
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
    SecondaryListScaffold() {
      if (this.topics.length === 0) {
        ListItem() {
          EmptyState({ message: '还没有稍后读主题', stateHeight: 220 })
        }
      } else {
        ForEach(this.topics, (item: SavedTopic) => {
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

  private topicSubtitle(item: SavedTopic): string {
    const parts: string[] = []
    const node = item.nodeTitle || item.nodeName
    if (node) {
      parts.push(node)
    }
    if (item.username) {
      parts.push(item.username)
    }
    parts.push(`保存于 ${DateUtils.toDateString(item.savedAt)}`)
    return parts.join(' · ')
  }
}
