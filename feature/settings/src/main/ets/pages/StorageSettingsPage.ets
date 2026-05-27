import { common } from '@kit.AbilityKit'
import type { BackupEnvelopeV1, CacheDeviceQaSeedResult, CacheStats } from 'shared'
import {
  AppStrings,
  BackupService,
  CacheDeviceQaSeed,
  CacheSettings,
  ConciseListRow,
  GroupedListSection,
  LocalDataSettings,
  SecondaryListScaffold,
  AccountStoreQaSeed
} from 'shared'
import BuildProfile from '../../../../BuildProfile'
import {
  SettingsDivider,
  SettingsSectionHeader
} from '../components/SettingsPageComponents'
import {
  StorageSettingsCoordinator,
  type StorageConfirmDialogCopy,
} from '../model/StorageSettingsCoordinator'
import { BackupFilePickerCoordinator } from '../model/BackupFilePickerCoordinator'

@Component
export struct StorageSettingsPage {
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
  @State private seedMessage: string = ''
  @State private localDataMessage: string = ''
  @State private backupMessage: string = ''
  @State private pendingBackupEnvelope: BackupEnvelopeV1 | null = null
  @State private accountSeedMessage: string = ''

  aboutToAppear(): void {
    this.loadCacheStats()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_OFFLINE_CACHE })
        }

        ListItem() {
          this.CacheSection()
        }

        if (BuildProfile.DEBUG && CacheDeviceQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: AppStrings.R_CACHE_QA_SEED })
          }

          ListItem() {
            this.CacheQaSeedSection()
          }
        }

        if (BuildProfile.DEBUG && AccountStoreQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: AppStrings.R_ACCOUNT_QA_SEED })
          }

          ListItem() {
            this.AccountQaSeedSection()
          }
        }

        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_BACKUP_SECTION })
        }

        ListItem() {
          this.BackupSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_LOCAL_DATA })
        }

        ListItem() {
          this.LocalDataSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_OFFLINE_CACHE,
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        showChevron: false
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_REFRESH_CACHE_STATUS,
        showChevron: false,
        action: () => {
          this.loadCacheStats()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_CLEAR_CACHE,
        subtitle: this.cacheMessage,
        destructive: true,
        showChevron: false,
        action: () => {
          this.confirmClearCache()
        }
      })
    }
  }

  @Builder
  BackupSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_EXPORT_BACKUP,
        subtitle: this.backupMessage || AppStrings.text(AppStrings.R_BACKUP_EXPORT_SUBTITLE, 'Back up settings and local data; login/session data is excluded.'),
        showChevron: false,
        action: () => {
          this.confirmExportBackup()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_IMPORT_BACKUP,
        subtitle: AppStrings.text(AppStrings.R_BACKUP_IMPORT_SUBTITLE, 'Preview backup contents before replacing local data.'),
        showChevron: false,
        action: () => {
          this.selectImportBackup()
        }
      })
    }
  }

  @Builder
  LocalDataSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_CLEAR_LOCAL_DATA,
        subtitle: this.localDataMessage,
        destructive: true,
        showChevron: false,
        action: () => {
          this.confirmClearLocalData()
        }
      })
    }
  }

  @Builder
  CacheQaSeedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_SEED_ALL_CACHE_SCENARIOS,
        subtitle: this.seedMessage,
        showChevron: false,
        action: () => {
          this.runSeedAll()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_LARGE_LIST_FILE_CACHE,
        showChevron: false,
        action: () => {
          this.runSeedAction('large', () => CacheDeviceQaSeed.seedLargeFileBackedList(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_MIXED_ROW_CACHE,
        showChevron: false,
        action: () => {
          this.runSeedAction('mixed', () => CacheDeviceQaSeed.seedMixedInlineFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_INVALID_PATH_ROW,
        showChevron: false,
        action: () => {
          this.runSeedAction('invalid', () => CacheDeviceQaSeed.seedInvalidPathRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_ORPHAN_FILE,
        showChevron: false,
        action: () => {
          this.runSeedAction('orphan', () => CacheDeviceQaSeed.seedOrphanPayloadFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_MISSING_FILE_ROW,
        showChevron: false,
        action: () => {
          this.runSeedAction('missing', () => CacheDeviceQaSeed.seedMissingFileRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_HASH_MISMATCH_ROW,
        showChevron: false,
        action: () => {
          this.runSeedAction('hash', () => CacheDeviceQaSeed.seedHashMismatchRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_VERIFY_HASH_REPAIR,
        showChevron: false,
        action: () => {
          this.runSeedAction('hash-read', () => CacheDeviceQaSeed.validateHashMismatchRepair(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_SEED_EXPIRED_ROW,
        showChevron: false,
        action: () => {
          this.runSeedAction('expired', () => CacheDeviceQaSeed.seedExpiredRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_RESET_SEED_CACHE,
        destructive: true,
        showChevron: false,
        action: () => {
          this.runSeedAction('reset', () => CacheDeviceQaSeed.resetSeededCache(this.hostContext()))
        }
      })
    }
  }

  @Builder
  AccountQaSeedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_SEED_ACCOUNT_RECORDS,
        subtitle: this.accountSeedMessage,
        showChevron: false,
        action: () => {
          this.runAccountSeedAction()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.R_RESET_SEEDED_ACCOUNTS,
        destructive: true,
        showChevron: false,
        action: () => {
          this.runAccountResetAction()
        }
      })
    }
  }

  private loadCacheStats(): void {
    const context = this.hostContext()
    CacheSettings.loadStats(context)
      .then((stats: CacheStats) => {
        this.cacheStats = stats
      })
      .catch((error: Error) => {
        this.cacheMessage = StorageSettingsCoordinator.readCacheErrorMessage(error)
        console.error('load cache stats failed: ' + error.message)
      })
  }

  private confirmClearCache(): void {
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.clearCacheDialogCopy()
    this.getUIContext().showAlertDialog({
      title: copy.title,
      message: copy.message,
      primaryButton: {
        value: copy.cancelValue, action: () => {
        }
      },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.clearCache()
        }
      }
    })
  }

  private clearCache(): void {
    const context = this.hostContext()
    CacheSettings.clear(context)
      .then(() => {
        this.cacheMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.cacheMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }

  private confirmClearLocalData(): void {
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.clearLocalDataDialogCopy()
    this.getUIContext().showAlertDialog({
      title: copy.title,
      message: copy.message,
      primaryButton: {
        value: copy.cancelValue, action: () => {
        }
      },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.clearLocalData()
        }
      }
    })
  }

  private clearLocalData(): void {
    const context = this.hostContext()
    LocalDataSettings.clearAll(context)
      .then(() => {
        this.cacheMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.localDataMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.localDataMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }

  private confirmExportBackup(): void {
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.backupExportDialogCopy()
    this.getUIContext().showAlertDialog({
      title: copy.title,
      message: copy.message,
      primaryButton: { value: copy.cancelValue, action: () => {} },
      secondaryButton: {
        value: copy.confirmValue,
        action: () => {
          this.exportBackup()
        }
      }
    })
  }

  private exportBackup(): void {
    BackupFilePickerCoordinator.exportBackup(this.hostContext(), { versionName: '0.7.0', versionCode: 8 })
      .then((_uri: string) => {
        this.backupMessage = StorageSettingsCoordinator.backupSuccessMessage(true)
      })
      .catch((error: Error) => {
        this.backupMessage = StorageSettingsCoordinator.backupErrorMessage(error.message)
      })
  }

  private selectImportBackup(): void {
    BackupFilePickerCoordinator.selectImport(this.hostContext())
      .then((selection) => {
        if (!selection.parseResult.ok || !selection.parseResult.envelope) {
          this.backupMessage = StorageSettingsCoordinator.backupErrorMessage(selection.parseResult.message)
          return
        }
        this.pendingBackupEnvelope = selection.parseResult.envelope
        const preview = BackupService.preview(selection.parseResult.envelope)
        const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.backupImportPreviewCopy(preview)
        this.getUIContext().showAlertDialog({
          title: copy.title,
          message: copy.message,
          primaryButton: { value: copy.cancelValue, action: () => {} },
          secondaryButton: {
            value: copy.confirmValue,
            action: () => {
              this.confirmImportBackup()
            }
          }
        })
      })
      .catch((error: Error) => {
        this.backupMessage = StorageSettingsCoordinator.backupErrorMessage(error.message)
      })
  }

  private confirmImportBackup(): void {
    if (!this.pendingBackupEnvelope) {
      return
    }
    const preview = BackupService.preview(this.pendingBackupEnvelope)
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.backupImportConfirmDialogCopy(preview)
    this.getUIContext().showAlertDialog({
      title: copy.title,
      message: copy.message,
      primaryButton: { value: copy.cancelValue, action: () => {} },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.restorePendingBackup()
        }
      }
    })
  }

  private restorePendingBackup(): void {
    const envelope = this.pendingBackupEnvelope
    if (!envelope) {
      return
    }
    BackupFilePickerCoordinator.restoreSelected(this.hostContext(), envelope)
      .then(() => {
        this.backupMessage = StorageSettingsCoordinator.backupSuccessMessage(false)
        this.pendingBackupEnvelope = null
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.backupMessage = StorageSettingsCoordinator.backupErrorMessage(error.message)
      })
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private runSeedAll(): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    CacheDeviceQaSeed.seedAll(this.hostContext())
      .then((results: CacheDeviceQaSeedResult[]) => {
        this.seedMessage = StorageSettingsCoordinator.seedAllSuccessMessage(results)
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runSeedAction(label: string, action: () => Promise<CacheDeviceQaSeedResult>): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    action()
      .then((result: CacheDeviceQaSeedResult) => {
        this.seedMessage = StorageSettingsCoordinator.seedActionSuccessMessage(label, result)
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runAccountSeedAction(): void {
    if (!BuildProfile.DEBUG || !AccountStoreQaSeed.isEnabled()) {
      this.accountSeedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    AccountStoreQaSeed.seedFakeAccounts(this.hostContext())
      .then((count: number) => {
        this.accountSeedMessage = `Seeded ${count} account record(s)`
      })
      .catch((error: Error) => {
        this.accountSeedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runAccountResetAction(): void {
    if (!BuildProfile.DEBUG || !AccountStoreQaSeed.isEnabled()) {
      this.accountSeedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    AccountStoreQaSeed.resetSeededAccounts(this.hostContext())
      .then(() => {
        this.accountSeedMessage = StorageSettingsCoordinator.clearSuccessMessage()
      })
      .catch((error: Error) => {
        this.accountSeedMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }
}
