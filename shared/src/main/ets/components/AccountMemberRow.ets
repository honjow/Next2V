import type { V2exAccountMemberListItem } from '../parser/V2exAccountListParser'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'

@ComponentV2
export struct AccountMemberRow {
  @Param item: V2exAccountMemberListItem = {
    username: '',
    avatar: '',
    subtitle: ''
  }
  @Param avatarPlaceholder: string = ''

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({
        url: this.item.avatar,
        avatarSize: 42,
        placeholder: this.avatarPlaceholder
      })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.item.username)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.item.subtitle) {
          Text(this.item.subtitle)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
