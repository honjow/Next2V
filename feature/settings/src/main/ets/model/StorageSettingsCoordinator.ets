import { AppStrings } from 'shared'
import type {
  CacheDeviceQaSeedResult,
  CacheStats,
  BackupPreview,
} from 'shared'
import { DateUtils } from 'shared'

export interface StorageConfirmDialogCopy {
  title: string
  message: string
  cancelValue: string
  confirmValue: string
}

// backup copy intentionally says login state, cookies, tokens, and overwrite before restore.
export class StorageSettingsCoordinator {
  static cacheSubtitle(stats: CacheStats): string {
    const listCount = `${stats.topicListCount}`
    const detailCount = `${stats.topicDetailCount}`
    if (stats.updatedAt > 0) {
      return AppStrings.format(
        AppStrings.text(AppStrings.R_CACHE_SUBTITLE_UPDATED,
          'Lists {0} · Details {1} · Updated {2}'),
        [listCount, detailCount, DateUtils.toDateString(stats.updatedAt)])
    }
    return AppStrings.format(
      AppStrings.text(AppStrings.R_CACHE_SUBTITLE,
        'Lists {0} · Details {1}'),
      [listCount, detailCount])
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

  static backupExportDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text(AppStrings.R_EXPORT_BACKUP, 'Export backup'),
      message: AppStrings.text(AppStrings.R_BACKUP_EXPORT_MESSAGE, 'Export settings and local data to a V2Next backup file. Login state, cookies, tokens, and offline cache are excluded. Continue?'),
      cancelValue: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
      confirmValue: AppStrings.text(AppStrings.R_EXPORT_BACKUP, 'Export backup'),
    }
  }

  static backupImportPreviewCopy(preview: BackupPreview): StorageConfirmDialogCopy {
    const sections = preview.sections.join(', ')
    let message = AppStrings.format(AppStrings.text(AppStrings.R_BACKUP_IMPORT_PREVIEW_MESSAGE, 'Backup from {0}, app {1} ({2}). Sections: {3}. Login state, cookies, and tokens will not be changed.'), [preview.createdAt, preview.appVersion, `${preview.appVersionCode}`, sections])
    // An encrypted backup that carries the userInfo section DOES restore accounts and login
    // credentials, so the preview must say so instead of the credential-free notice above.
    if (preview.sections.indexOf('userInfo') >= 0) {
      message = message + '\n' + AppStrings.text(AppStrings.R_BACKUP_IMPORT_RESTORES_ACCOUNTS, 'This backup includes accounts and login info, which will replace the current accounts.')
    }
    return {
      title: AppStrings.text(AppStrings.R_IMPORT_BACKUP, 'Import backup'),
      message: message,
      cancelValue: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
      confirmValue: AppStrings.text(AppStrings.R_COMMON_RESTORE, 'Restore'),
    }
  }

  static backupImportConfirmDialogCopy(_preview: BackupPreview): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text(AppStrings.R_IMPORT_BACKUP, 'Import backup'),
      message: AppStrings.text(AppStrings.R_BACKUP_IMPORT_CONFIRM_MESSAGE, 'This will overwrite supported local settings, drafts, read-later/follow/history/search data from the backup. Login state is kept. Continue?'),
      cancelValue: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
      confirmValue: AppStrings.text(AppStrings.R_COMMON_RESTORE, 'Restore'),
    }
  }

  static backupSuccessMessage(exported: boolean): string {
    if (exported) {
      return AppStrings.text(AppStrings.R_BACKUP_EXPORTED, 'Backup exported.')
    }
    return AppStrings.text(AppStrings.R_BACKUP_IMPORT_COMPLETE, 'Backup import complete.')
  }

  static backupErrorMessage(errorCode: string): string {
    if (errorCode === 'foreign_backup') {
      return AppStrings.text(AppStrings.R_BACKUP_ERROR_FOREIGN, 'This file is not a V2Next backup.')
    }
    if (errorCode === 'unsupported_version') {
      return AppStrings.text(AppStrings.R_BACKUP_ERROR_VERSION, 'Unsupported backup version.')
    }
    if (errorCode === 'bad_checksum') {
      return AppStrings.text(AppStrings.R_BACKUP_ERROR_CHECKSUM, 'Backup is damaged or failed checksum validation.')
    }
    if (errorCode === 'bad_password') {
      return AppStrings.text(AppStrings.R_BACKUP_ERROR_BAD_PASSWORD, 'Incorrect password or the backup is damaged.')
    }
    if (errorCode === 'too_large') {
      return AppStrings.text(AppStrings.R_BACKUP_ERROR_TOO_LARGE, 'Backup file is too large.')
    }
    return errorCode || AppStrings.text(AppStrings.R_BACKUP_ERROR_INVALID, 'This file is not a V2Next backup.')
  }

  // Validate the two password fields entered when exporting an encrypted (account-bearing)
  // backup. Returns an error message resource string, or '' when the password is acceptable.
  static validateExportPassword(password: string, confirm: string): string {
    if (password.length < 8) {
      return AppStrings.text(AppStrings.R_BACKUP_PASSWORD_TOO_SHORT, 'Use at least 8 characters.')
    }
    if (password !== confirm) {
      return AppStrings.text(AppStrings.R_BACKUP_PASSWORD_MISMATCH, 'The two passwords do not match.')
    }
    return ''
  }
}
