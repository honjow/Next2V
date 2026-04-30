import {
  V2exReply,
  V2exTopic,
  Avatar,
  UserName,
  TimeAgo,
  NodeTag,
  ReplyCard,
  ThemeConstants,
  NodeTopicListParams,
  TopicDetailParams
} from 'shared'
import { webview } from '@kit.ArkWeb'
import { DetailViewModel } from '../viewmodel/DetailViewModel'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State viewModel: DetailViewModel = new DetailViewModel(this.topicId)
  @Consume('pageStack') pageStack: NavPathStack
  @State headerOpacity: number = 0
  private scroller: Scroller = new Scroller()
  private readonly fadeThreshold: number = 120

  aboutToAppear(): void {
    this.viewModel.load()
  }

  build() {
    NavDestination() {
      if (this.viewModel.isLoading && this.viewModel.topic === null) {
        Column() {
          LoadingProgress()
            .width(32).height(32)
            .color($r('sys.color.font_secondary'))
          Text('加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: ThemeConstants.SPACE_MD })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%').height('100%')
      } else {
        Stack() {
          List({ scroller: this.scroller }) {
            ListItem() {
              TopicHeader({
                topic: this.viewModel.topic!,
                onNodeClick: (nodeName: string, nodeTitle: string) => {
                  let p: NodeTopicListParams = { nodeName: nodeName, nodeTitle: nodeTitle }
                  this.pageStack.pushPathByName('NodeTopicList', p)
                }
              })
            }

            ListItem() {
              Text(`共 ${this.viewModel.replyDataSource.totalCount()} 条回复`)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .padding(ThemeConstants.SPACE_LG)
                .width('100%')
            }

            LazyForEach(this.viewModel.replyDataSource, (reply: V2exReply, index: number) => {
              ListItem() {
                ReplyCard({
                  reply: reply,
                  floor: index + 1,
                  isOp: this.viewModel.topic !== null && reply.member.id === this.viewModel.topic.member.id
                })
              }
            }, (reply: V2exReply) => reply.id.toString())
          }
          .onScroll((_x: number, y: number) => {
            this.headerOpacity = Math.min(y / this.fadeThreshold, 1.0)
          })
          .width('100%').height('100%')
          .padding({ top: 0 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

          // floating toolbar
          Row() {
            Text(this.viewModel.topic?.node.title || '主题详情')
              .fontSize(18)
              .fontColor($r('sys.color.font_primary'))
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 44, bottom: 10 })
          .backgroundColor(`rgba(255, 255, 255, ${this.headerOpacity * 0.92})`)
          .backgroundBlurStyle(BlurStyle.Regular, {
            scale: this.headerOpacity
          })
          .opacity(this.headerOpacity > 0.05 ? 1 : 0)
          .animation({ duration: 100, curve: Curve.EaseOut })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        }
        .width('100%').height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .hideTitleBar(true)
  }
}

@Component
struct TopicHeader {
  @Prop topic: V2exTopic
  onNodeClick: (nodeName: string, nodeTitle: string) => void = () => {}

  build() {
    Column() {
      Text(this.topic.title)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ top: 60 })

      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({ url: this.topic.member.avatar_normal, avatarSize: 36 })
        Column() {
          UserName({ username: this.topic.member.username })
          TimeAgo({ timestamp: this.topic.created })
        }
        Blank()
        NodeTag({ nodeName: this.topic.node.name, nodeTitle: this.topic.node.title })
          .onClick(() => this.onNodeClick(this.topic.node.name, this.topic.node.title))
      }
      .width('100%')
      .margin({ top: ThemeConstants.SPACE_LG })

      if (this.topic.content_rendered) {
        Web({ src: wrapHtmlContent(this.topic.content_rendered), controller: new webview.WebviewController() })
          .width('100%')
          .height(300)
          .darkMode(WebDarkMode.Auto)
          .margin({ top: ThemeConstants.SPACE_LG })
      } else if (this.topic.content) {
        Text(this.topic.content)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(22)
          .width('100%')
          .margin({ top: ThemeConstants.SPACE_LG })
      }

      Divider()
        .margin({ top: ThemeConstants.SPACE_XL, bottom: ThemeConstants.SPACE_MD })
    }
    .padding(ThemeConstants.SPACE_LG)
  }
}

function wrapHtmlContent(bodyHtml: string): string {
  return `<html><head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body { font-family: system-ui; font-size: 16px; line-height: 1.6; color: inherit; padding: 0; margin: 0; }
      img { max-width: 100%; height: auto; }
      a { color: #334455; }
      pre { background: #f0f0f0; padding: 12px; border-radius: 4px; overflow-x: auto; }
      code { font-size: 14px; }
      blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 12px; color: #666; }
    </style></head><body>${bodyHtml}</body></html>`
}
