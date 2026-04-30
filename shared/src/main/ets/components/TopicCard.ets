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
    Row() {
      Avatar({ url: this.item.member.avatar_normal, avatarSize: 40 })
        .margin({ right: ThemeConstants.SPACE_MD })
        .onClick(() => {
          if (this.onUserClick) { this.onUserClick() }
        })

      Column() {
        Row({ space: ThemeConstants.SPACE_SM }) {
          UserName({ username: this.item.member.username, fontSize: 13 })
          NodeTag({ nodeName: this.item.node.name, nodeTitle: this.item.node.title })
          Blank()
          TimeAgo({ timestamp: this.item.last_touched })
        }.width('100%').alignItems(VerticalAlign.Center)

        Text(this.item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE).fontColor($r('sys.color.font_primary'))
          .lineHeight(22).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').margin({ top: ThemeConstants.SPACE_XS })

        Row() {
          Blank()
          Text(`${this.item.replies} 回复`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary'))
        }.width('100%').margin({ top: ThemeConstants.SPACE_XS })
      }.layoutWeight(1)
    }
    .padding(ThemeConstants.SPACE_LG).borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary')).width('100%')
  }
}
