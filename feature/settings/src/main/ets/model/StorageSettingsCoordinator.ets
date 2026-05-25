import { AppStrings } from 'shared'
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
  static cacheSubtitle(stats: CacheStats): ResourceStr {
    const listCount = `${stats.topicListCount}`
    const detailCount = `${stats.topicDetailCount}`
    if (stats.updatedAt > 0) {
      return $r('app.string.cache_subtitle_updated', listCount, detailCount, DateUtils.toDateString(stats.updatedAt))
    }
    return $r('app.string.cache_subtitle', listCount, detailCount)
  }

  static clearCacheDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text(AppStrings.R_CLEAR_CACHE, 'Clear cache'),
      message: AppStrings.text(AppStrings.R_CLEAR_CACHE_MESSAGE, 'Only offline cache will be cleared. Login state and preferences will be kept. Continue?'),
      cancelValue: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
      confirmValue: AppStrings.text(AppStrings.R_COMMON_CLEAR, 'Clear'),
    }
  }

  static clearLocalDataDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text(AppStrings.R_CLEAR_LOCAL_DATA, 'Clear local data'),
      message: AppStrings.text(AppStrings.R_CLEAR_LOCAL_DATA_MESSAGE, 'This clears locally saved read later items, followed nodes, recently viewed items, read state, drafts, search history, notification cache, and offline cache. Login state and preferences are kept. Continue?'),
      cancelValue: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
      confirmValue: AppStrings.text(AppStrings.R_COMMON_CLEAR, 'Clear'),
    }
  }

  static clearSuccessMessage(): string {
    return AppStrings.text(AppStrings.R_COMMON_CLEARED, 'Cleared')
  }

  static readCacheErrorMessage(error: Error): string {
    return error.message || AppStrings.text(AppStrings.R_READ_CACHE_STATUS_FAILED, 'Failed to read cache status')
  }

  static clearErrorMessage(error: Error): string {
    return error.message || AppStrings.text(AppStrings.R_CLEAR_FAILED, 'Clear failed')
  }

  static seedUnavailableMessage(): string {
    return AppStrings.text(AppStrings.R_DEBUG_ONLY, 'Debug builds only')
  }

  static seedAllSuccessMessage(results: CacheDeviceQaSeedResult[]): string {
    const rows = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededRows, 0)
    const files = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededFiles, 0)
    return AppStrings.format(AppStrings.text(AppStrings.R_STORAGE_WRITTEN_FORMAT, 'Wrote {0} rows / {1} files'), [`${rows}`, `${files}`])
  }

  static seedActionSuccessMessage(label: string, result: CacheDeviceQaSeedResult): string {
    return AppStrings.format(AppStrings.text(AppStrings.R_STORAGE_SEEDED_LABEL_FORMAT, '{0}: {1} rows / {2} files'), [label, `${result.seededRows}`, `${result.seededFiles}`])
  }

  static seedErrorMessage(error: Error): string {
    return error.message || AppStrings.text(AppStrings.R_SEED_FAILED, 'Seed failed')
  }
}
