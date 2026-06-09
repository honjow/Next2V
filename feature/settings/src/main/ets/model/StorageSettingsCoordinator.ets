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
        AppStrings.text($r('app.string.cache_subtitle_updated'),
          'Lists {0} · Details {1} · Updated {2}'),
        [listCount, detailCount, DateUtils.toDateString(stats.updatedAt)])
    }
    return AppStrings.format(
      AppStrings.text($r('app.string.cache_subtitle'),
        'Lists {0} · Details {1}'),
      [listCount, detailCount])
  }

  static clearCacheDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text($r('app.string.clear_cache'), 'Clear cache'),
      message: AppStrings.text($r('app.string.clear_cache_message'), 'Only offline cache will be cleared. Login state and preferences will be kept. Continue?'),
      cancelValue: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmValue: AppStrings.text($r('app.string.common_clear'), 'Clear'),
    }
  }

  static clearLocalDataDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text($r('app.string.clear_local_data'), 'Clear local data'),
      message: AppStrings.text($r('app.string.clear_local_data_message'), 'This clears locally saved read later items, followed nodes, recently viewed items, read state, drafts, search history, notification cache, and offline cache. Login state and preferences are kept. Continue?'),
      cancelValue: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmValue: AppStrings.text($r('app.string.common_clear'), 'Clear'),
    }
  }

  static clearSuccessMessage(): string {
    return AppStrings.text($r('app.string.common_cleared'), 'Cleared')
  }

  static readCacheErrorMessage(error: Error): string {
    return error.message || AppStrings.text($r('app.string.read_cache_status_failed'), 'Failed to read cache status')
  }

  static clearErrorMessage(error: Error): string {
    return error.message || AppStrings.text($r('app.string.clear_failed'), 'Clear failed')
  }

  static seedUnavailableMessage(): string {
    return AppStrings.text($r('app.string.debug_only'), 'Debug builds only')
  }

  static seedAllSuccessMessage(results: CacheDeviceQaSeedResult[]): string {
    const rows = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededRows, 0)
    const files = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededFiles, 0)
    return AppStrings.format(AppStrings.text($r('app.string.storage_written_format'), 'Wrote {0} rows / {1} files'), [`${rows}`, `${files}`])
  }

  static seedActionSuccessMessage(label: string, result: CacheDeviceQaSeedResult): string {
    return AppStrings.format(AppStrings.text($r('app.string.storage_seeded_label_format'), '{0}: {1} rows / {2} files'), [label, `${result.seededRows}`, `${result.seededFiles}`])
  }

  static seedErrorMessage(error: Error): string {
    return error.message || AppStrings.text($r('app.string.seed_failed'), 'Seed failed')
  }

  static backupExportDialogCopy(): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text($r('app.string.export_backup'), 'Export backup'),
      message: AppStrings.text($r('app.string.backup_export_message'), 'Export settings and local data to a V2Next backup file. Login state, cookies, tokens, and offline cache are excluded. Continue?'),
      cancelValue: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmValue: AppStrings.text($r('app.string.export_backup'), 'Export backup'),
    }
  }

  static backupImportPreviewCopy(preview: BackupPreview): StorageConfirmDialogCopy {
    const sections = preview.sections.join(', ')
    let message = AppStrings.format(AppStrings.text($r('app.string.backup_import_preview_message'), 'Backup from {0}, app {1} ({2}). Sections: {3}. Login state, cookies, and tokens will not be changed.'), [preview.createdAt, preview.appVersion, `${preview.appVersionCode}`, sections])
    // An encrypted backup that carries the userInfo section DOES restore accounts and login
    // credentials, so the preview must say so instead of the credential-free notice above.
    if (preview.sections.indexOf('userInfo') >= 0) {
      message = message + '\n' + AppStrings.text($r('app.string.backup_import_restores_accounts'), 'This backup includes accounts and login info, which will replace the current accounts.')
    }
    return {
      title: AppStrings.text($r('app.string.import_backup'), 'Import backup'),
      message: message,
      cancelValue: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmValue: AppStrings.text($r('app.string.common_restore'), 'Restore'),
    }
  }

  static backupImportConfirmDialogCopy(_preview: BackupPreview): StorageConfirmDialogCopy {
    return {
      title: AppStrings.text($r('app.string.import_backup'), 'Import backup'),
      message: AppStrings.text($r('app.string.backup_import_confirm_message'), 'This will overwrite supported local settings, drafts, read-later/follow/history/search data from the backup. Login state is kept. Continue?'),
      cancelValue: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmValue: AppStrings.text($r('app.string.common_restore'), 'Restore'),
    }
  }

  static backupSuccessMessage(exported: boolean): string {
    if (exported) {
      return AppStrings.text($r('app.string.backup_exported'), 'Backup exported.')
    }
    return AppStrings.text($r('app.string.backup_import_complete'), 'Backup import complete.')
  }

  static backupErrorMessage(errorCode: string): string {
    if (errorCode === 'foreign_backup') {
      return AppStrings.text($r('app.string.backup_error_foreign'), 'This file is not a V2Next backup.')
    }
    if (errorCode === 'unsupported_version') {
      return AppStrings.text($r('app.string.backup_error_version'), 'Unsupported backup version.')
    }
    if (errorCode === 'bad_checksum') {
      return AppStrings.text($r('app.string.backup_error_checksum'), 'Backup is damaged or failed checksum validation.')
    }
    if (errorCode === 'bad_password') {
      return AppStrings.text($r('app.string.backup_error_bad_password'), 'Incorrect password or the backup is damaged.')
    }
    if (errorCode === 'too_large') {
      return AppStrings.text($r('app.string.backup_error_too_large'), 'Backup file is too large.')
    }
    return errorCode || AppStrings.text($r('app.string.backup_error_invalid'), 'This file is not a V2Next backup.')
  }

  // Validate the two password fields entered when exporting an encrypted (account-bearing)
  // backup. Returns an error message resource string, or '' when the password is acceptable.
  static validateExportPassword(password: string, confirm: string): string {
    if (password.length < 8) {
      return AppStrings.text($r('app.string.backup_password_too_short'), 'Use at least 8 characters.')
    }
    if (password !== confirm) {
      return AppStrings.text($r('app.string.backup_password_mismatch'), 'The two passwords do not match.')
    }
    return ''
  }
}
