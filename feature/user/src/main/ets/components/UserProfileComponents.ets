import {
  Avatar,
  AppStrings,
  DateUtils,
  MarkdownContent,
  ThemeConstants,
  UserMarkBadgeRow,
  V2exMemberProfile,
  V2exUserReply
} from 'shared'

function defaultProfile(): V2exMemberProfile {
  return {
    status: '',
    id: 0,
    url: '',
    username: '',
    website: '',
    twitter: '',
    psn: '',
    github: '',
    btc: '',
    location: '',
    tagline: '',
    bio: '',
    avatar_mini: '',
    avatar_normal: '',
    avatar_large: '',
    created: 0
  }
}

@ComponentV2
export struct UserProfileLoadingState {
  build() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

@ComponentV2
export struct UserProfileErrorState {
  @Param message: string = ''
  @Event retryAction?: () => void

  build() {
    Column() {
      Text(this.message || AppStrings.text($r('app.string.common_load_failed'), 'Load failed'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button(AppStrings.text($r('app.string.common_retry'), 'Retry'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          if (this.retryAction) {
            this.retryAction()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
export struct UserProfileCard {
  @Param profile: V2exMemberProfile = defaultProfile()
  @Param displayUsername: string = ''
  @Event onUsernameAreaChange?: (bottom: number) => void

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({
          url: this.profile.avatar_large || this.profile.avatar_normal,
          avatarSize: 72,
        })
        Column({ space: ThemeConstants.SPACE_XS }) {
          Row({ space: ThemeConstants.SPACE_XS }) {
            Text(this.displayUsername || this.profile.username)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(1)
            UserMarkBadgeRow({
              username: this.displayUsername || this.profile.username,
              fontSize: ThemeConstants.FONT_SIZE_TAG
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            if (this.onUsernameAreaChange) {
              this.onUsernameAreaChange(
                this.areaY(newValue?.globalPosition?.y) + this.areaLength(newValue?.height)
              )
            }
          })
          if (this.profile.tagline) {
            Text(this.profile.tagline)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(AppStrings.format(
            AppStrings.text($r('app.string.user_profile_member_number'), 'Member #{0} · {1}'),
            [String(this.profile.id), DateUtils.toDateString(this.profile.created)]
          ))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.profile.bio) {
        Text(this.profile.bio)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY + 2)
          .width('100%')
      }

      this.ProfileMeta()
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private ProfileMeta() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.profile.location) {
        this.MetaRow(AppStrings.text($r('app.string.user_profile_location'), 'Location'), this.profile.location)
      }
      if (this.profile.website) {
        this.MetaRow(AppStrings.text($r('app.string.user_profile_website'), 'Website'), this.profile.website)
      }
      if (this.profile.github) {
        this.MetaRow('GitHub', this.profile.github)
      }
      if (this.profile.twitter) {
        this.MetaRow('Twitter', this.profile.twitter)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder private MetaRow(label: string, value: string) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width(56)
      Text(value)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private areaY(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private areaLength(value: Length | undefined): number {
    return this.areaY(value)
  }
}

@ComponentV2
export struct UserProfileAllActivityButton {
  @Param label: string = ''
  @Event openAction?: () => void

  build() {
    Button(this.label)
      .type(ButtonType.Capsule)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_primary'))
      .height(40)
      .width('100%')
      .onClick(() => {
        if (this.openAction) {
          this.openAction()
        }
      })
  }
}

@ComponentV2
export struct UserProfileEmptyCard {
  @Param message: string = ''

  build() {
    Text(this.message)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}

@ComponentV2
export struct UserProfileReplyCard {
  @Param reply: V2exUserReply = {
    topic_id: 0,
    topic_title: '',
    target_floor: 0,
    node_name: '',
    node_title: '',
    topic_author: '',
    content: '',
    created: 0
  }
  @Param fallbackUsername: string = ''
  @Event openTopic?: () => void
  @Event openLink?: (url: string) => void
  @Event openImage?: (url: string) => void
  @Event openMention?: (username: string) => void
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
          },
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
