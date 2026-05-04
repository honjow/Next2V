import { V2exTopic } from '../network/NetworkTypes'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { UserName } from './UserName'
import { TimeAgo } from './TimeAgo'
import { NodeTag } from './NodeTag'

@Component
export struct TopicCard {
  @Prop item: V2exTopic
  onUserClick?: () => void

  build() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({ url: this.item.member.avatar_normal, avatarSize: ThemeConstants.AVATAR_SIZE_REPLY })
          .onClick(() => {
            if (this.onUserClick) { this.onUserClick() }
          })
        UserName({ username: this.item.member.username, fontSize: ThemeConstants.FONT_SIZE_META })
        NodeTag({ nodeName: this.item.node.name, nodeTitle: this.item.node.title })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_XS })

      Row({ space: ThemeConstants.SPACE_XS }) {
        Blank()
        if (this.item.replies > 0) {
          Text('最后回复来自')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
          Text(this.item.last_reply_by || this.item.member.username)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_emphasize'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
          TimeAgo({ timestamp: this.item.last_touched })
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        Text(`${this.item.replies} 回复`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .margin({ top: ThemeConstants.SPACE_XS })
    }
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .width('100%')
  }
}
