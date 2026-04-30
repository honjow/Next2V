import { V2exTopic, ApiService, ThemeConstants, TopicDetailParams } from 'shared'
import { FeedViewModel } from '../viewmodel/FeedViewModel'
import { FeedList } from '../components/FeedList'

@Component
export struct FeedTabNavigation {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack()

  @Builder
  pageMap(name: string, param: object) {
    if (name === 'FeedLatest') {
      FeedLatestPageInner()
    } else if (name === 'TopicDetail') {
      TopicDetailPage({ topicId: (param as TopicDetailParams).topicId })
    }
  }

  build() {
    Navigation(this.pageStack) {
      FeedLatestPageInner()
    }
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .height('100%')
  }
}

@Component
struct FeedLatestPageInner {
  @State viewModel: FeedViewModel = new FeedViewModel()
  @Consume('pageStack') pageStack: NavPathStack

  aboutToAppear(): void {
    this.viewModel.loadData()
  }

  build() {
    NavDestination() {
      FeedList({
        viewModel: this.viewModel,
        onTopicClick: (topic: V2exTopic) => {
          let p: TopicDetailParams = { topicId: topic.id }
          this.pageStack.pushPathByName('TopicDetail', p)
        }
      })
    }
    .hideTitleBar(false)
    .title('最新')
  }
}

@Component
struct TopicDetailPage {
  @Prop topicId: number

  build() {
    NavDestination() {
      Text('加载中...')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .title('详情')
  }
}
