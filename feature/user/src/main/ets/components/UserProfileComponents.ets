import {
  Avatar,
  DateUtils,
  MarkdownContent,
  ThemeConstants,
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

@Component
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

@Component
export struct UserProfileErrorState {
  @Prop message: string = ''
  retryAction?: () => void

  build() {
    Column() {
      Text(this.message || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
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

@Component
export struct UserProfileCard {
  @Prop profile: V2exMemberProfile = defaultProfile()
  @Prop displayUsername: string = ''
  onUsernameAreaChange?: (bottom: number) => void

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({
          url: this.profile.avatar_large || this.profile.avatar_normal,
          avatarSize: 72,
        })
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.displayUsername || this.profile.username)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
          Text(`第 ${this.profile.id} 号会员 · ${DateUtils.toDateString(this.profile.created)}`)
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
        this.MetaRow('位置', this.profile.location)
      }
      if (this.profile.website) {
        this.MetaRow('网站', this.profile.website)
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

@Component
export struct UserProfileAllActivityButton {
  @Prop label: string = ''
  openAction?: () => void

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

@Component
export struct UserProfileEmptyCard {
  @Prop message: string = ''

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

@Component
export struct UserProfileReplyCard {
  @Prop reply: V2exUserReply = {
    topic_id: 0,
    topic_title: '',
    target_floor: 0,
    node_name: '',
    node_title: '',
    topic_author: '',
    content: '',
    created: 0
  }
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
          },
        })
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
