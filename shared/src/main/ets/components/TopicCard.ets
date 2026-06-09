import { V2exTopic } from '../network/NetworkTypes'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { UserName } from './UserName'
import { TimeAgo } from './TimeAgo'
import { NodeTag } from './NodeTag'
import { ImageUtils } from '../utils/ImageUtils'
import { AppStrings } from '../i18n/AppStrings'

@ComponentV2
export struct TopicCard {
  @Require @Param item: V2exTopic
  @Param isUnread: boolean = false
  @Param metaLabel: string = AppStrings.text(AppStrings.R_TOPIC_LAST_REPLY, 'Last reply')
  @Param metaTimestamp: number = 0
  @Param showReplyCount: boolean = true
  @Param showNodeTag: boolean = true
  @Event onUserClick?: () => void
  @Event onNodeClick?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({
          url: ImageUtils.memberAvatarUrl(this.item.member),
          avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
          placeholder: this.item.member.username
        })
          .onClick(() => {
            if (this.onUserClick) { this.onUserClick() }
          })
        Column() {
          UserName({
            username: this.item.member.username,
            fontSize: ThemeConstants.FONT_SIZE_META,
            isPro: this.isMemberPro(),
            isMod: this.isMemberMod(),
            onUserClick: () => {
              if (this.onUserClick) { this.onUserClick() }
            }
          })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.isPinned()) {
          this.PinnedBadge()
        }
        if (this.showNodeTag) {
          NodeTag({ nodeName: this.item.node.name, nodeTitle: this.item.node.title })
            .onClick(() => {
              if (this.onNodeClick) { this.onNodeClick() }
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        Text(this.item.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_XS }) {
        if (this.item.replies > 0 || this.metaTimestamp > 0) {
          Text(this.metaLabel)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
          if (this.shouldShowLastReplyUser()) {
            Text(this.lastReplyUsername())
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('·')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
          }
          TimeAgo({ timestamp: this.metaTimestamp > 0 ? this.metaTimestamp : this.item.last_touched })
          if (this.showReplyCount) {
            Text('·')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        if (this.showReplyCount) {
          Text(AppStrings.format(
            AppStrings.text(AppStrings.R_TOPIC_REPLIES_COUNT, '{0} replies'),
            [`${this.item.replies}`]))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.End)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_SM + 2,
      bottom: ThemeConstants.SPACE_SM + 2
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .width('100%')
  }

  private isMemberPro(): boolean {
    return (this.item.member.pro || 0) > 0
  }

  private isMemberMod(): boolean {
    return (this.item.member.mod || 0) > 0
  }

  private isPinned(): boolean {
    return (this.item.pinned || 0) > 0
  }

  private lastReplyUsername(): string {
    return (this.item.last_reply_by || '').trim()
  }

  private shouldShowLastReplyUser(): boolean {
    return this.metaTimestamp <= 0 && this.lastReplyUsername().length > 0
  }

  @Builder
  private PinnedBadge() {
    Text(AppStrings.text(AppStrings.R_TOPIC_PINNED_BADGE, 'Pinned'))
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS / 2,
        bottom: ThemeConstants.SPACE_XS / 2
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .flexShrink(0)
  }
}
