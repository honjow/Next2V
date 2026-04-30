import { DateUtils } from '../utils/DateUtils'

@Component
export struct TimeAgo {
  @Prop timestamp: number = 0

  build() {
    Text(DateUtils.toRelativeTime(this.timestamp))
      .fontSize(12)
      .fontColor($r('sys.color.font_secondary'))
  }
}
