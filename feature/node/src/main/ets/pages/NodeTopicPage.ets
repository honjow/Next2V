import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, UserProfileParams
} from 'shared'

@Component
export struct NodeTopicPage {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @StorageProp('topAvoidHeight') topH: number = 0

  aboutToAppear(): void { this.vm.loadNodeTopics(this.nodeName) }

  build() {
    Column() {
      if (this.vm.isLoading) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      } else {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }
          ForEach(this.vm.nodeTopics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                onUserClick: () => {
                  let p: UserProfileParams = { username: topic.member.username }
                  this.stack.pushPathByName('UserProfile', p as Object)
                }
              })
            }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          })
        }
          .scrollBar(BarState.Off)
          .width('100%').height('100%')
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
