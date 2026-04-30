import { DateUtils } from '../utils/DateUtils'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct TimeAgo {
  @Prop timestamp: number = 0

  build() {
    Text(DateUtils.toRelativeTime(this.timestamp))
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
  }
}
