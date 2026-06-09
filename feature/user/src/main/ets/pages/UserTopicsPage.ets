import { UserTopicsViewModel } from '../viewmodel/UserViewModel'
import {
  AppStrings, CardEmptyState, connectNavStack, connectTopicReadStates, NodeTopicListParams, PageErrorState,
  PageLoadingState, SecondaryListScaffold, TopicCard, TopicDetailParams, TopicReadStatesState, V2exTopic
} from 'shared'
import type { TopicReadState } from 'shared'

@ComponentV2
export struct UserTopicsPage {
  @Param username: string = ''
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack
  @Local vm: UserTopicsViewModel = new UserTopicsViewModel(this.username)
  // V2 mirror of TOPIC_READ_STATES (LocalDataPublisher dual-writes V1 AppStorage + this).
  private readStates: TopicReadStatesState = connectTopicReadStates()

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.topicDataSource.totalCount() === 0) {
        PageLoadingState()
      } else if (this.vm.topicsHidden) {
        CardEmptyState({ message: $r('app.string.user_topics_hidden') })
      } else if (this.vm.errorMessage && this.vm.topicDataSource.totalCount() === 0) {
        PageErrorState({
          message: this.vm.errorMessage || AppStrings.text($r('app.string.common_load_failed'), 'Load failed'),
          retryAction: () => {
            this.vm.load()
          }
        })
      } else if (this.vm.topicDataSource.totalCount() === 0) {
        CardEmptyState({ message: AppStrings.text($r('app.string.user_profile_no_topics'), 'No topics') })
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
      const parsed = JSON.parse(this.readStates.statesJson || '[]') as TopicReadState[]
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
