/**
 * 时间格式化工具
 */
export class DateUtils {
  /** Unix 秒时间戳转为相对时间字符串 */
  static toRelativeTime(unixSeconds: number): string {
    const now = Date.now() / 1000
    const diff = now - unixSeconds

    if (diff < 60) {
      return '刚刚'
    }
    if (diff < 3600) {
      return `${Math.floor(diff / 60)} 分钟前`
    }
    if (diff < 86400) {
      return `${Math.floor(diff / 3600)} 小时前`
    }
    if (diff < 2592000) {
      return `${Math.floor(diff / 86400)} 天前`
    }
    if (diff < 31536000) {
      return `${Math.floor(diff / 2592000)} 个月前`
    }
    return `${Math.floor(diff / 31536000)} 年前`
  }

  /** Unix 秒时间戳转为格式化日期 */
  static toDateString(unixSeconds: number): string {
    const date = new Date(unixSeconds * 1000)
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, '0')
    const d = String(date.getDate()).padStart(2, '0')
    const h = String(date.getHours()).padStart(2, '0')
    const min = String(date.getMinutes()).padStart(2, '0')
    return `${y}-${m}-${d} ${h}:${min}`
  }
}
