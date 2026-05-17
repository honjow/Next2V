import {
  DateUtils,
  MarkdownContent,
  ThemeConstants,
  V2exUserReply
} from 'shared'

function defaultReply(): V2exUserReply {
  return {
    topic_id: 0,
    topic_title: '',
    topic_author: '',
    node_name: '',
    node_title: '',
    content: '',
    created: 0,
    target_floor: 0
  }
}

@Component
export struct UserRepliesCard {
  @Prop reply: V2exUserReply = defaultReply()
  @Prop fallbackUsername: string = ''
  openLink?: (url: string) => void
  openMention?: (username: string) => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        Text(this.reply.topic_author || this.fallbackUsername)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text('›')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.reply.node_title || this.reply.node_name)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        if (this.reply.created > 0) {
          Text(DateUtils.toDateString(this.reply.created))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')

      Text(this.reply.topic_title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.reply.content) {
        MarkdownContent({
          source: this.reply.content,
          topMargin: 0,
          onLinkClick: (url: string) => {
            if (this.openLink) {
              this.openLink(url)
            }
          },
          onMentionClick: (username: string) => {
            if (this.openMention) {
              this.openMention(username)
            }
          }
        })
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
