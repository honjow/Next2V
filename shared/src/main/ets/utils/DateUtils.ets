const SECONDS_PER_MINUTE: number = 60
const SECONDS_PER_HOUR: number = 3600
const SECONDS_PER_DAY: number = 86400
const SECONDS_PER_MONTH: number = 2592000
const SECONDS_PER_YEAR: number = 31536000
const MS_PER_SECOND: number = 1000

/**
 * 时间格式化工具
 */
export class DateUtils {
  /** Unix 秒时间戳转为相对时间字符串 */
  static toRelativeTime(unixSeconds: number): string {
    const now = Date.now() / MS_PER_SECOND
    const diff = now - unixSeconds

    if (diff < SECONDS_PER_MINUTE) {
      return '刚刚'
    }
    if (diff < SECONDS_PER_HOUR) {
      return `${Math.floor(diff / SECONDS_PER_MINUTE)} 分钟前`
    }
    if (diff < SECONDS_PER_DAY) {
      return `${Math.floor(diff / SECONDS_PER_HOUR)} 小时前`
    }
    if (diff < SECONDS_PER_MONTH) {
      return `${Math.floor(diff / SECONDS_PER_DAY)} 天前`
    }
    if (diff < SECONDS_PER_YEAR) {
      return `${Math.floor(diff / SECONDS_PER_MONTH)} 个月前`
    }
    return `${Math.floor(diff / SECONDS_PER_YEAR)} 年前`
  }

  /** Unix 秒时间戳转为格式化日期 */
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
