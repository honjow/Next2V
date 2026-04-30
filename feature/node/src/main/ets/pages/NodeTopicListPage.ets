import { V2exTopic, TopicCard, ThemeConstants, TopicDetailParams } from 'shared'
import { NodeViewModel } from '../viewmodel/NodeViewModel'

@Component
export struct NodeTopicListPage {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @State viewModel: NodeViewModel = new NodeViewModel()
  @Consume('pageStack') pageStack: NavPathStack

  aboutToAppear(): void {
    this.viewModel.loadNodeTopics(this.nodeName)
  }

  build() {
    NavDestination() {
      if (this.viewModel.isLoading) {
        Column() {
          LoadingProgress()
            .width(32).height(32)
          Text('加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: ThemeConstants.SPACE_MD })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%').height('100%')
      } else {
        List({ space: ThemeConstants.SPACE_XS }) {
          ForEach(this.viewModel.nodeTopics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({ item: topic })
                .onClick(() => {
                  let p: TopicDetailParams = { topicId: topic.id }
                  this.pageStack.pushPathByName('TopicDetail', p)
                })
            }
          })
        }
        .width('100%').height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .hideTitleBar(false)
    .title(this.nodeTitle || this.nodeName)
  }
}
