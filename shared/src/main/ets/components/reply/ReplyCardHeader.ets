import { V2exReply } from '../../network/NetworkTypes'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { ImageUtils } from '../../utils/ImageUtils'
import { Avatar } from '../Avatar'
import { TimeAgo } from '../TimeAgo'
import { UserName } from '../UserName'
import { ReplyCardActions } from './ReplyCardActions'

@ComponentV2
export struct ReplyCardHeader {
  @Require @Param reply: V2exReply;
  @Param floor: number = 1;
  @Param isOp: boolean = false;
  @Param isDuplicateThreadItem: boolean = false;
  @Param isCompact: boolean = false;
  // When the compact header is too narrow to fit the username, timestamp and the three action
  // buttons on one line, stack the timestamp under the username and collapse the actions into a
  // single overflow menu. The parent ReplyCard computes this from the measured card width.
  @Param isNarrow: boolean = false;
  @Param showCompactMarkOverflow: boolean = true;
  @Param isThanked: boolean = false;
  @Param isThankPending: boolean = false;
  @Event onUserClick?: (reply: V2exReply) => void;
  @Event onActionsClick?: (reply: V2exReply) => void;
  @Event onContextClick?: (reply: V2exReply) => void;
  @Event onReplyClick?: (reply: V2exReply) => void;
  @Event onThankClick?: (reply: V2exReply) => void;
  @Event onIgnoreClick?: (reply: V2exReply) => void;
  @Event onReportClick?: (reply: V2exReply) => void;
  @Event onCopyUserClick?: (reply: V2exReply) => void;
  @Event onCopyContentClick?: (reply: V2exReply) => void;

  @Builder
  Username() {
    // flexShrink so a long username ellipsizes instead of pushing the timestamp / actions / floor
    // off the row (the source of the compact-header overflow), rather than wrapping to a new line.
    UserName({
      username: this.reply.member.username,
      fontSize: ThemeConstants.FONT_SIZE_META,
      fontWeight: FontWeight.Medium,
      isPro: (this.reply.member.pro || 0) > 0,
      markVisibleLimit: this.isCompact ? 1 : 0,
      markShowOverflow: !this.isCompact || (!this.isNarrow && this.showCompactMarkOverflow),
      markMaxWidth: this.isCompact ? (this.isNarrow ? 70 : 76) : 92,
      onUserClick: () => {
        if (this.onUserClick) {
          this.onUserClick(this.reply)
        }
      }
    })
      .flexShrink(1)
  }

  @Builder
  OpBadge() {
    if (this.isOp) {
      Text('OP')
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor($r('sys.color.font_on_primary'))
        .padding({
          left: ThemeConstants.SPACE_XS + 2,
          right: ThemeConstants.SPACE_XS + 2,
          top: 1,
          bottom: 1,
        })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor($r('sys.color.ohos_id_color_activated'))
    }
  }

  @Builder
  DupBadge() {
    if (this.isDuplicateThreadItem) {
      Text('DUP')
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor($r('sys.color.font_secondary'))
        .padding({
          left: ThemeConstants.SPACE_XS + 2,
          right: ThemeConstants.SPACE_XS + 2,
          top: 1,
          bottom: 1,
        })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    }
  }

  @Builder
  Actions() {
    ReplyCardActions({
      reply: this.reply,
      isThanked: this.isThanked,
      isThankPending: this.isThankPending,
      collapsed: this.isNarrow,
      onActionsClick: this.onActionsClick,
      onContextClick: this.onContextClick,
      onReplyClick: this.onReplyClick,
      onThankClick: this.onThankClick,
      onIgnoreClick: this.onIgnoreClick,
      onReportClick: this.onReportClick,
      onCopyUserClick: this.onCopyUserClick,
      onCopyContentClick: this.onCopyContentClick,
    })
  }

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Avatar({
        url: ImageUtils.memberAvatarUrl(this.reply.member),
        avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
      })
        .onClick(() => {
          if (this.onUserClick) {
            this.onUserClick(this.reply)
          }
        })

      if (this.isCompact && this.isNarrow) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Row({ space: ThemeConstants.SPACE_SM }) {
            this.Username()
            this.OpBadge()
            this.DupBadge()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          TimeAgo({ timestamp: this.reply.created })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      } else {
        Row({ space: ThemeConstants.SPACE_SM }) {
          this.Username()
          this.OpBadge()
          this.DupBadge()
          if (this.isCompact) {
            TimeAgo({ timestamp: this.reply.created })
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
      }

      if (this.isCompact) {
        this.Actions()
      }
      Text(`#${this.floor}`)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
