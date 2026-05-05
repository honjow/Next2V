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
  private readonly GAP: number = ThemeConstants.SPACE_SM

  aboutToAppear(): void { this.vm.loadNodeTopics(this.nodeName) }

  build() {
    Column() {
      if (this.vm.isLoading) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      } else if (this.vm.errorMessage) {
        this.ErrorView()
      } else if (this.vm.nodeTopics.length === 0) {
        this.EmptyView()
      } else {
        List({ space: this.GAP }) {
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
          .padding({ left: this.GAP, right: this.GAP })
          .width('100%').height('100%')
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder EmptyView() {
    Column() {
      Text('暂无主题')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage || '节点主题加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.loadNodeTopics(this.nodeName) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}
