import { AppStrings } from '../i18n/AppStrings'

const SECONDS_PER_MINUTE: number = 60
const SECONDS_PER_HOUR: number = 3600
const SECONDS_PER_DAY: number = 86400
const SECONDS_PER_MONTH: number = 2592000
const SECONDS_PER_YEAR: number = 31536000
const MS_PER_SECOND: number = 1000

/**
 * Time formatting utilities.
 */
export class DateUtils {
  /** Unix timestamp (seconds) to relative time string, localized via AppStrings. */
  static toRelativeTime(unixSeconds: number): string {
    const now = Date.now() / MS_PER_SECOND
    const diff = now - unixSeconds

    if (diff < SECONDS_PER_MINUTE) {
      return AppStrings.text($r('app.string.relative_just_now'), 'Just now')
    }
    if (diff < SECONDS_PER_HOUR) {
      return AppStrings.format(
        AppStrings.text($r('app.string.relative_minutes_ago'), '{0} min ago'),
        [String(Math.floor(diff / SECONDS_PER_MINUTE))]
      )
    }
    if (diff < SECONDS_PER_DAY) {
      return AppStrings.format(
        AppStrings.text($r('app.string.relative_hours_ago'), '{0} h ago'),
        [String(Math.floor(diff / SECONDS_PER_HOUR))]
      )
    }
    if (diff < SECONDS_PER_MONTH) {
      return AppStrings.format(
        AppStrings.text($r('app.string.relative_days_ago'), '{0} d ago'),
        [String(Math.floor(diff / SECONDS_PER_DAY))]
      )
    }
    if (diff < SECONDS_PER_YEAR) {
      return AppStrings.format(
        AppStrings.text($r('app.string.relative_months_ago'), '{0} mo ago'),
        [String(Math.floor(diff / SECONDS_PER_MONTH))]
      )
    }
    return AppStrings.format(
      AppStrings.text($r('app.string.relative_years_ago'), '{0} y ago'),
      [String(Math.floor(diff / SECONDS_PER_YEAR))]
    )
  }

  /** Convert Unix second timestamp to formatted date */
  static toDateString(unixSeconds: number): string {
    const date = new Date(unixSeconds * MS_PER_SECOND)
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, '0')
    const d = String(date.getDate()).padStart(2, '0')
    const h = String(date.getHours()).padStart(2, '0')
    const min = String(date.getMinutes()).padStart(2, '0')
    return `${y}-${m}-${d} ${h}:${min}`
  }
}
