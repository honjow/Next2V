import { V2exReply } from '../network/NetworkTypes'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { UserName } from './UserName'
import { TimeAgo } from './TimeAgo'

@Component
export struct ReplyCard {
  @Prop reply: V2exReply
  @Prop floor: number = 1
  @Prop isOp: boolean = false

  build() {
    Column() {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({ url: this.reply.member.avatar_mini, avatarSize: 32 })
        Column() {
          Row({ space: ThemeConstants.SPACE_SM }) {
            UserName({ username: this.reply.member.username, fontSize: 13 })
            if (this.isOp) {
              Text('OP')
                .fontSize(10)
                .fontColor($r('sys.color.font_on_primary'))
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .borderRadius(2)
                .backgroundColor($r('sys.color.ohos_id_color_activated'))
            }
            Blank()
            Text(`#${this.floor}`)
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
          }
          TimeAgo({ timestamp: this.reply.created })
        }
        .layoutWeight(1)
      }
      .width('100%')

      Text(this.reply.content)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_SM })

      if (this.reply.thanks > 0) {
        Row() {
          Text(`♥ ${this.reply.thanks}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_emphasize'))
        }
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_XS })
      }
    }
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD
    })
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
