import { V2exTopic } from '../network/NetworkTypes'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { UserName } from './UserName'
import { TimeAgo } from './TimeAgo'
import { NodeTag } from './NodeTag'
import { ImageUtils } from '../utils/ImageUtils'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

@ComponentV2
export struct TopicCard {
  @Require @Param item: V2exTopic
  @Param isUnread: boolean = false
  @Param metaLabel: ResourceStr = $r('app.string.topic_last_reply')
  @Param metaTimestamp: number = 0
  @Param showReplyCount: boolean = true
  @Param showNodeTag: boolean = true
  @Event onUserClick?: () => void
  @Event onNodeClick?: () => void
  private language: LanguageState = connectLanguageState()

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
        if (this.shouldShowMeta()) {
          if (this.shouldShowMetaLabel()) {
            Text(this.localeAwareResource(this.metaLabel))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
          }
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
          TimeAgo({ timestamp: this.metaTime() })
          if (this.showReplyCount) {
            Text('·')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        if (this.showReplyCount) {
          Text(AppStrings.format(
            AppStrings.text($r('app.string.topic_replies_count'), '{0} replies'),
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
    .backgroundColor($r('app.color.card_background'))
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

  private metaTime(): number {
    if (this.metaTimestamp > 0) {
      return this.metaTimestamp
    }
    if (this.item.replies > 0) {
      return this.item.last_touched > 0 ? this.item.last_touched : (this.item.last_modified > 0 ? this.item.last_modified : this.item.created)
    }
    return this.item.created > 0 ? this.item.created : (this.item.last_touched > 0 ? this.item.last_touched : this.item.last_modified)
  }

  private shouldShowMeta(): boolean {
    return this.metaTime() > 0
  }

  private shouldShowMetaLabel(): boolean {
    return this.metaTimestamp > 0 || this.item.replies > 0
  }

  private shouldShowLastReplyUser(): boolean {
    return this.metaTimestamp <= 0 && this.item.replies > 0 && this.lastReplyUsername().length > 0
  }

  @Builder
  private PinnedBadge() {
    Text(AppStrings.text($r('app.string.topic_pinned_badge'), 'Pinned'))
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

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }
}
