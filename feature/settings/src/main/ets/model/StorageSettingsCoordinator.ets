import type {
  CacheDeviceQaSeedResult,
  CacheStats,
} from 'shared'
import { DateUtils } from 'shared'

export interface StorageConfirmDialogCopy {
  title: string
  message: string
  cancelValue: string
  confirmValue: string
}

export class StorageSettingsCoordinator {
  static cacheSubtitle(stats: CacheStats): string {
    let text = `列表 ${stats.topicListCount} 组 · 详情 ${stats.topicDetailCount} 篇`
    if (stats.updatedAt > 0) {
      text += ` · 更新于 ${DateUtils.toDateString(stats.updatedAt)}`
    }
    return text
  }

  static clearCacheDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: '清理缓存',
      message: '将只清理离线缓存，不会清理登录状态或偏好设置。确定继续吗？',
      cancelValue: '取消',
      confirmValue: '清理',
    }
  }

  static clearLocalDataDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: '清理本地数据',
      message: '将清理本机保存的稍后读、关注节点、最近浏览、已读状态、草稿、搜索历史、通知缓存和离线缓存。登录状态与偏好设置会保留。确定继续吗？',
      cancelValue: '取消',
      confirmValue: '清理',
    }
  }

  static clearSuccessMessage(): string {
    return '已清理'
  }

  static readCacheErrorMessage(error: Error): string {
    return error.message || '读取缓存状态失败'
  }

  static clearErrorMessage(error: Error): string {
    return error.message || '清理失败'
  }

  static seedUnavailableMessage(): string {
    return '仅 debug 构建可用'
  }

  static seedAllSuccessMessage(results: CacheDeviceQaSeedResult[]): string {
    const rows = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededRows, 0)
    const files = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededFiles, 0)
    return `已写入 ${rows} 行 / ${files} 文件`
  }

  static seedActionSuccessMessage(label: string, result: CacheDeviceQaSeedResult): string {
    return `${label}: ${result.seededRows} 行 / ${result.seededFiles} 文件`
  }

  static seedErrorMessage(error: Error): string {
    return error.message || 'Seed 失败'
  }
}
