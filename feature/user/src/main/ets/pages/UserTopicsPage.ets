import { UserTopicsViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, NodeTopicListParams,
  SecondaryListScaffold
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
      SecondaryListScaffold({
        onReachEnd: () => {
          this.vm.loadMore()
        }
      }) {
        if (this.vm.isLoading && this.vm.topicDataSource.totalCount() === 0) {
          ListItem() { this.LoadingView() }
        } else if (this.vm.topicsHidden) {
          ListItem() { this.EmptyText('主题列表已隐藏') }
        } else if (this.vm.errorMessage && this.vm.topicDataSource.totalCount() === 0) {
          ListItem() { this.ErrorView() }
        } else if (this.vm.topicDataSource.totalCount() === 0) {
          ListItem() { this.EmptyText('暂无主题') }
        } else {
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
            ListItem() { this.LoadingView(80) }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LoadingView(height: number = 240) {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(height)
  }

  @Builder EmptyText(text: string) {
    Text(text)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .type(ButtonType.Capsule)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.load() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
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
