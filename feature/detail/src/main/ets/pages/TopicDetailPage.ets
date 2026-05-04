import { DetailViewModel } from '../viewmodel/DetailViewModel'
import {
  V2exReply, Avatar, ReplyCard, ThemeConstants
} from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State v: DetailViewModel = new DetailViewModel(0)
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 0

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.v.load()
  }

  build() {
    Column() {
      if (this.v.isLoading && this.v.topic === null) {
        this.LoadingView()
      } else if (this.v.errorMessage && this.v.topic === null) {
        this.ErrorView()
      } else if (this.v.topic !== null) {
        this.ContentView()
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color($r('sys.color.ohos_id_color_activated'))
      Text('加载中...')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%').height('100%')
  }

  @Builder ErrorView() {
    Column() {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_secondary')])
      Text(this.v.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.v.load() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%').height('100%')
  }

  @Builder ContentView() {
    List() {
      // 顶部安全区占位
      ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }

      // 主楼卡片（标题 + 元信息 + 正文）
      ListItem() {
        this.TopicCard()
      }
      .margin({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: ThemeConstants.SPACE_SM
      })

      // 回复分隔
      ListItem() {
        this.ReplyDivider()
      }

      // 回复列表
      LazyForEach(this.v.replyDataSource, (reply: V2exReply, index: number) => {
        ListItem() {
          ReplyCard({
            reply: reply,
            floor: index + 1,
            isOp: this.v.topic !== null && reply.member.id === this.v.topic!.member.id
          })
        }
        .margin({
          left: ThemeConstants.SPACE_MD,
          right: ThemeConstants.SPACE_MD,
          bottom: ThemeConstants.SPACE_SM - 2
        })
      }, (reply: V2exReply) => reply.id.toString())

      // 底部留白
      ListItem() { Column() { Blank().height(ThemeConstants.SPACE_XL) } }
    }
    .scrollBar(BarState.Off)
    .width('100%').height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder TopicCard() {
    Column() {
      // 发布者信息
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({ url: this.v.topic!.member.avatar_normal, avatarSize: ThemeConstants.AVATAR_SIZE_REPLY })

        Text(this.v.topic!.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Blank()

        Text(this.v.topic!.node.title)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.ohos_id_color_activated'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 标题
      Text(this.v.topic!.title)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING + 2)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_MD })

      // 正文
      if (this.v.topic!.content) {
        Text(this.v.topic!.content)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY + 2)
          .width('100%')
          .margin({ top: ThemeConstants.SPACE_LG })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ReplyDivider() {
    Row() {
      Text(`共 ${this.v.replyDataSource.totalCount()} 条回复`)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_SM
    })
  }
}
