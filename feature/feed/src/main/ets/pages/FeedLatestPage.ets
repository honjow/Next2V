import { V2exTopic, ThemeConstants, TopicDetailParams } from 'shared'
import { FeedViewModel } from '../viewmodel/FeedViewModel'
import { FeedList } from '../components/FeedList'

@Component
export struct FeedLatestPage {
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
