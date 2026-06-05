import { ThemeConstants } from '../theme/ThemeConstants'
import { UserMarkBadgeRow } from './UserMarkBadges'

@ComponentV2
export struct UserName {
  @Param username: string = ''
  @Param fontSize: number = 14
  @Param fontWeight: FontWeight = FontWeight.Regular
  @Param isPro: boolean = false
  @Param showUserMarks: boolean = true
  @Param markFontSize: number = ThemeConstants.FONT_SIZE_TINY
  @Param markVisibleLimit: number = 0
  @Param markShowOverflow: boolean = true
  @Param markMaxWidth: number = 92
  @Event onUserClick?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.username)
        .fontSize(this.fontSize)
        .fontWeight(this.fontWeight)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
        .onClick(() => {
          if (this.onUserClick) { this.onUserClick() }
        })
      if (this.isPro) {
        Text('PRO')
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .lineHeight(10)
          .padding({
            left: 3,
            right: 3,
            top: 1,
            bottom: 1
          })
          .border({ width: 1, color: '#1484CD', radius: 3 })
          .backgroundColor('#323A45')
      }
      if (this.showUserMarks) {
        UserMarkBadgeRow({
          username: this.username,
          fontSize: this.markFontSize,
          visibleLimit: this.markVisibleLimit,
          showOverflow: this.markShowOverflow,
          maxBadgeWidth: this.markMaxWidth,
        })
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
