import { common } from '@kit.AbilityKit'
import type { CacheDeviceQaSeedResult, CacheStats } from 'shared'
import {
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
          SettingsSectionHeader({ title: '离线缓存' })
        }

        ListItem() {
          this.CacheSection()
        }

        if (BuildProfile.DEBUG && CacheDeviceQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: '缓存 QA Seed' })
          }

          ListItem() {
            this.CacheQaSeedSection()
          }
        }

        ListItem() {
          SettingsSectionHeader({ title: '本地数据' })
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
        title: '离线缓存',
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        showChevron: false
      })

      SettingsDivider()

      ConciseListRow({
        title: '刷新缓存状态',
        showChevron: false,
        action: () => {
          this.loadCacheStats()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: '清理缓存',
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
        title: '清理本地数据',
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
        title: 'Seed 全部缓存场景',
        subtitle: this.seedMessage,
        showChevron: false,
        action: () => {
          this.runSeedAll()
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 大列表文件缓存',
        showChevron: false,
        action: () => {
          this.runSeedAction('large', () => CacheDeviceQaSeed.seedLargeFileBackedList(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 混合行缓存',
        showChevron: false,
        action: () => {
          this.runSeedAction('mixed', () => CacheDeviceQaSeed.seedMixedInlineFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 非法路径行',
        showChevron: false,
        action: () => {
          this.runSeedAction('invalid', () => CacheDeviceQaSeed.seedInvalidPathRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 孤立文件',
        showChevron: false,
        action: () => {
          this.runSeedAction('orphan', () => CacheDeviceQaSeed.seedOrphanPayloadFile(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 缺失文件行',
        showChevron: false,
        action: () => {
          this.runSeedAction('missing', () => CacheDeviceQaSeed.seedMissingFileRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed Hash 不匹配行',
        showChevron: false,
        action: () => {
          this.runSeedAction('hash', () => CacheDeviceQaSeed.seedHashMismatchRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: '验证 Hash 修复',
        showChevron: false,
        action: () => {
          this.runSeedAction('hash-read', () => CacheDeviceQaSeed.validateHashMismatchRepair(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: 'Seed 过期行',
        showChevron: false,
        action: () => {
          this.runSeedAction('expired', () => CacheDeviceQaSeed.seedExpiredRow(this.hostContext()))
        }
      })

      SettingsDivider()

      ConciseListRow({
        title: '重置 Seed 缓存',
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
