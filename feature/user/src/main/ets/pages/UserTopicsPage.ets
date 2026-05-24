import { UserTopicsViewModel } from '../viewmodel/UserViewModel'
import {
  AppStrings, CardEmptyState, NodeTopicListParams, PageErrorState, PageLoadingState, SecondaryListScaffold,
  StorageKeys, TopicCard, TopicDetailParams, V2exTopic
} from 'shared'
import type { TopicReadState } from 'shared'

@Component
export struct UserTopicsPage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserTopicsViewModel = new UserTopicsViewModel(this.username)
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.topicDataSource.totalCount() === 0) {
        PageLoadingState()
      } else if (this.vm.topicsHidden) {
        CardEmptyState({ message: $r('app.string.user_topics_hidden') })
      } else if (this.vm.errorMessage && this.vm.topicDataSource.totalCount() === 0) {
        PageErrorState({
          message: this.vm.errorMessage || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed'),
          retryAction: () => {
            this.vm.load()
          }
        })
      } else if (this.vm.topicDataSource.totalCount() === 0) {
        CardEmptyState({ message: AppStrings.text(AppStrings.R_USER_PROFILE_NO_TOPICS, 'No topics') })
      } else {
        SecondaryListScaffold({
          onReachEnd: () => {
            this.vm.loadMore()
          }
        }) {
          LazyForEach(this.vm.topicDataSource, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                isUnread: this.isTopicUnread(topic),
                onNodeClick: () => {
                  let p: NodeTopicListParams = { nodeName: topic.node.name, nodeTitle: topic.node.title }
                  this.stack.pushPathByName('NodeTopicList', p as Object)
                }
              })
            }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: topic.id }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
          }, (topic: V2exTopic) => topic.id.toString())

          if (this.vm.isLoadingMore) {
            ListItem() {
              PageLoadingState({ stateHeight: 80, expand: false })
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }
}
