import { DetailViewModel } from '../viewmodel/DetailViewModel'
import {
  V2exTopic, V2exReply, TopicCard, ReplyCard, ThemeConstants, TopicDetailParams, StorageKeys
} from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State v: DetailViewModel = new DetailViewModel(this.topicId)
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 0

  aboutToAppear(): void { this.v.load() }

  build() {
    Column() {
      if (this.v.isLoading && this.v.topic === null) {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE_LARGE).height(ThemeConstants.LOADING_SIZE_LARGE)
          Text('加载中...').fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_MD })
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      } else if (this.v.topic !== null) {
        List() {
          ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }
          ListItem() {
            Column() {
              Text(this.v.topic!.title).fontSize(ThemeConstants.FONT_SIZE_HEADING + 2).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary')).lineHeight(28).width('100%')
              Row({ space: ThemeConstants.SPACE_SM }) {
                Text(this.v.topic!.member.username).fontSize(ThemeConstants.FONT_SIZE_META).fontColor($r('sys.color.font_secondary'))
                Text('·').fontSize(ThemeConstants.FONT_SIZE_META).fontColor($r('sys.color.font_secondary'))
                Text(this.v.topic!.node.title).fontSize(ThemeConstants.FONT_SIZE_META).fontColor($r('sys.color.ohos_id_color_activated'))
              }.width('100%').margin({ top: ThemeConstants.SPACE_MD })
            }.padding(ThemeConstants.SPACE_LG).width('100%')
          }
          ListItem() {
            Text(`共 ${this.v.replyDataSource.totalCount()} 条回复`).fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor($r('sys.color.font_secondary'))
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG }).width('100%')
          }
          LazyForEach(this.v.replyDataSource, (reply: V2exReply, index: number) => {
            ListItem() {
              ReplyCard({
                reply: reply,
                floor: index + 1,
                isOp: this.v.topic !== null && reply.member.id === this.v.topic!.member.id
              })
            }
              .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_SM - 2 })
          }, (reply: V2exReply) => reply.id.toString())
        }
          .scrollBar(BarState.Off)
          .width('100%').height('100%')
      } else {
        Text('加载失败').fontSize(ThemeConstants.FONT_SIZE_TITLE).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
