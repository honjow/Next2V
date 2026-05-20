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
  openTopic?: () => void
  openLink?: (url: string) => void
  openImage?: (url: string) => void
  openMention?: (username: string) => void
  private inlineActionInFlight: boolean = false
  private primaryActionInFlight: boolean = false

  private replyBodySource(): string {
    const rendered = (this.reply.content_rendered || '').trim()
    if (rendered.length > 0) {
      return this.reply.content_rendered || ''
    }
    return this.reply.content || ''
  }

  private replyTimeText(): string {
    if (this.reply.created > 0) {
      return DateUtils.toDateString(this.reply.created)
    }
    return (this.reply.created_text || '').trim()
  }

  private runInlineAction(action: () => void): void {
    this.inlineActionInFlight = true
    action()
    setTimeout(() => {
      this.inlineActionInFlight = false
    }, 0)
  }

  private openPrimaryTopic(): void {
    if (this.inlineActionInFlight || this.primaryActionInFlight) {
      return
    }
    this.primaryActionInFlight = true
    setTimeout(() => {
      this.primaryActionInFlight = false
    }, 0)
    if (this.openTopic) {
      this.openTopic()
    }
  }

  @Builder private ReplyCardContent() {
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
        if (this.replyTimeText()) {
          Text(this.replyTimeText())
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        .onClick(() => {
          this.openPrimaryTopic()
        })

      if (this.replyBodySource()) {
        MarkdownContent({
          source: this.replyBodySource(),
          topMargin: 0,
          contentSelectable: false,
          onContentClick: () => {
            this.openPrimaryTopic()
          },
          onLinkClick: (url: string) => {
            this.runInlineAction(() => {
              if (this.openLink) {
                this.openLink(url)
              }
            })
          },
          onImageClick: (url: string) => {
            this.runInlineAction(() => {
              if (this.openImage) {
                this.openImage(url)
              }
            })
          },
          onMentionClick: (username: string) => {
            this.runInlineAction(() => {
              if (this.openMention) {
                this.openMention(username)
              }
            })
          }
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.ReplyCardContent()
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openPrimaryTopic()
    })
  }
}
