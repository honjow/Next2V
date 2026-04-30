import { DetailViewModel } from '../viewmodel/DetailViewModel'
import {
  V2exTopic, V2exReply, TopicCard, ThemeConstants, TopicDetailParams
} from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State v: DetailViewModel = new DetailViewModel(this.topicId)
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 107

  aboutToAppear(): void { this.v.load() }

  build() {
    Column() {
      if (this.v.isLoading && this.v.topic === null) {
        Column() {
          LoadingProgress().width(36).height(36)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 12 })
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      } else if (this.v.topic !== null) {
        List() {
          ListItem() { Column() { Blank().height(this.topH + 56) } }
          ListItem() {
            Column() {
              Text(this.v.topic!.title).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary')).lineHeight(28).width('100%')
              Row({ space: 8 }) {
                Text(this.v.topic!.member.username).fontSize(13).fontColor($r('sys.color.font_secondary'))
                Text('·').fontSize(13).fontColor($r('sys.color.font_secondary'))
                Text(this.v.topic!.node.title).fontSize(13).fontColor($r('sys.color.ohos_id_color_activated'))
              }.width('100%').margin({ top: 12 })
            }.padding(16).width('100%')
          }
          ListItem() {
            Text(`共 ${this.v.replyDataSource.totalCount()} 条回复`).fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .padding({ left: 12, right: 12, top: 16, bottom: 16 }).width('100%')
          }
          LazyForEach(this.v.replyDataSource, (reply: V2exReply) => {
            ListItem() {
              Column() {
                Row({ space: 8 }) {
                  Text(reply.member.username).fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                  Text(`#${reply.id}`).fontSize(11).fontColor($r('sys.color.font_secondary'))
                  Blank()
                  if (this.v.topic !== null && reply.member.id === this.v.topic!.member.id) {
                    Text('楼主').fontSize(10).fontColor($r('sys.color.ohos_id_color_activated'))
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 }).borderRadius(3)
                      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                  }
                }.width('100%')
                Text(reply.content).fontSize(14).fontColor($r('sys.color.font_primary'))
                  .lineHeight(22).margin({ top: 12 }).width('100%')
              }
                .padding(16).width('100%').borderRadius(8)
                .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
            }
              .margin({ left: 12, right: 12, bottom: 6 })
          }, (reply: V2exReply) => reply.id.toString())
        }
          .scrollBar(BarState.Off)
          .width('100%').height('100%')
      } else {
        Text('加载失败').fontSize(16).fontColor($r('sys.color.font_secondary')).margin({ top: 100 })
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
