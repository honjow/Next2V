import { common } from '@kit.AbilityKit'
import type { CacheDeviceQaSeedResult, CacheStats } from 'shared'
import {
  AppStrings,
  CacheDeviceQaSeed,
  CacheSettings,
  ConciseListRow,
  GroupedListSection,
  LocalDataSettings,
  SecondaryListScaffold
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

@Component
export struct StorageSettingsPage {
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
  @State private seedMessage: string = ''
  @State private localDataMessage: string = ''

  aboutToAppear(): void {
    this.loadCacheStats()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.t(AppStrings.R_OFFLINE_CACHE, 'Offline cache') })
        }

        ListItem() {
          this.CacheSection()
        }

        if (BuildProfile.DEBUG && CacheDeviceQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: AppStrings.t(AppStrings.R_CACHE_QA_SEED, 'Cache QA Seed') })
          }

          ListItem() {
            this.CacheQaSeedSection()
          }
        }

        ListItem() {
          SettingsSectionHeader({ title: AppStrings.t(AppStrings.R_LOCAL_DATA, 'Local data') })
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
        title: AppStrings.t(AppStrings.R_OFFLINE_CACHE, 'Offline cache'),
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        showChevron: false
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_REFRESH_CACHE_STATUS, 'Refresh cache status'),
        showChevron: false,
        action: () => {
          this.loadCacheStats()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_CLEAR_CACHE, 'Clear cache'),
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
  LocalDataSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.t(AppStrings.R_CLEAR_LOCAL_DATA, 'Clear local data'),
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
        title: AppStrings.t(AppStrings.R_SEED_ALL_CACHE_SCENARIOS, 'Seed all cache scenarios'),
        subtitle: this.seedMessage,
        showChevron: false,
        action: () => {
          this.runSeedAll()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_LARGE_LIST_FILE_CACHE, 'Seed large list file cache'),
        showChevron: false,
        action: () => {
          this.runSeedAction('large', () => CacheDeviceQaSeed.seedLargeFileBackedList(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_MIXED_ROW_CACHE, 'Seed mixed row cache'),
        showChevron: false,
        action: () => {
          this.runSeedAction('mixed', () => CacheDeviceQaSeed.seedMixedInlineFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_INVALID_PATH_ROW, 'Seed invalid path row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('invalid', () => CacheDeviceQaSeed.seedInvalidPathRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_ORPHAN_FILE, 'Seed orphan file'),
        showChevron: false,
        action: () => {
          this.runSeedAction('orphan', () => CacheDeviceQaSeed.seedOrphanPayloadFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_MISSING_FILE_ROW, 'Seed missing file row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('missing', () => CacheDeviceQaSeed.seedMissingFileRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_HASH_MISMATCH_ROW, 'Seed hash mismatch row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('hash', () => CacheDeviceQaSeed.seedHashMismatchRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_VERIFY_HASH_REPAIR, 'Verify hash repair'),
        showChevron: false,
        action: () => {
          this.runSeedAction('hash-read', () => CacheDeviceQaSeed.validateHashMismatchRepair(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_SEED_EXPIRED_ROW, 'Seed expired row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('expired', () => CacheDeviceQaSeed.seedExpiredRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: AppStrings.t(AppStrings.R_RESET_SEED_CACHE, 'Reset seed cache'),
        destructive: true,
        showChevron: false,
        action: () => {
          this.runSeedAction('reset', () => CacheDeviceQaSeed.resetSeededCache(this.hostContext()))
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
}
