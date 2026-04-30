import { V2exTopic, V2exReply, ApiService } from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State t: V2exTopic | null = null
  @State r: V2exReply[] = []
  @State l: boolean = true
  @StorageProp('topAvoidHeight') topH: number = 107
  private a: ApiService = new ApiService()

  aboutToAppear(): void { this.load() }

  async load(): Promise<void> {
    this.l = true
    try {
      let x = await this.a.getTopicById(this.topicId)
      if (x.length > 0) this.t = x[0]
      this.r = await this.a.getReplies(this.topicId)
    } catch (e) {}
    this.l = false
  }

  build() {
    Column() {
      if (this.l) {
        Column() {
          LoadingProgress().width(36).height(36)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 12 })
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      } else if (this.t !== null) {
        List() {
          ListItem() { Column() { Blank().height(this.topH + 56) } }
          ListItem() {
            Column() {
              Text(this.t!.title).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary')).lineHeight(28).width('100%')
              Row({ space: 8 }) {
                Text(this.t!.member.username).fontSize(13).fontColor($r('sys.color.font_secondary'))
                Text('·').fontSize(13).fontColor($r('sys.color.font_secondary'))
                Text(this.t!.node.title).fontSize(13).fontColor($r('sys.color.ohos_id_color_activated'))
              }.width('100%').margin({ top: 12 })
            }.padding(16).width('100%')
          }
          ListItem() {
            Text(`共 ${this.r.length} 条回复`).fontSize(13).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 12, right: 12, top: 16, bottom: 16 }).width('100%')
          }
          ForEach(this.r, (reply: V2exReply, index: number) => {
            ListItem() {
              Column() {
                Row({ space: 8 }) {
                  Text(reply.member.username).fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                  Text(`#${index + 1}`).fontSize(11).fontColor($r('sys.color.font_secondary'))
                  Blank()
                  if (this.t !== null && reply.member.id === this.t!.member.id) {
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
          })
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
