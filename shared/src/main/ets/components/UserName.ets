import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct UserName {
  @Prop username: string = ''
  @Prop fontSize: number = 14
  @Prop isPro: boolean = false
  onUserClick?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.username)
        .fontSize(this.fontSize)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
    }
    .alignItems(VerticalAlign.Center)
  }
}
