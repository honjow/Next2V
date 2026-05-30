import { V2exReply } from '../../network/NetworkTypes'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { ImageUtils } from '../../utils/ImageUtils'
import { Avatar } from '../Avatar'
import { TimeAgo } from '../TimeAgo'
import { ReplyCardActions } from './ReplyCardActions'

@ComponentV2
export struct ReplyCardHeader {
  @Require @Param reply: V2exReply;
  @Param floor: number = 1;
  @Param isOp: boolean = false;
  @Param isDuplicateThreadItem: boolean = false;
  @Param isCompact: boolean = false;
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
      Text(this.reply.member.username)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .onClick(() => {
          if (this.onUserClick) {
            this.onUserClick(this.reply)
          }
        })

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

      if (this.isCompact) {
        TimeAgo({ timestamp: this.reply.created })
      }
      Blank()

      if (this.isCompact) {
        ReplyCardActions({
          reply: this.reply,
          isThanked: this.isThanked,
          isThankPending: this.isThankPending,
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
      Text(`#${this.floor}`)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
