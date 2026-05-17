import { common } from '@kit.AbilityKit'
import type { CacheDeviceQaSeedResult, CacheStats } from 'shared'
import {
  CacheDeviceQaSeed,
  CacheSettings,
  ConciseListRow,
  DateUtils,
  GroupedListSection,
  ListDivider as SharedListDivider,
  LocalDataSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ThemeConstants
} from 'shared'
import BuildProfile from '../../../../BuildProfile'

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
          this.SectionHeader('离线缓存')
        }

        ListItem() {
          this.CacheSection()
        }

        if (BuildProfile.DEBUG && CacheDeviceQaSeed.isEnabled()) {
          ListItem() {
            this.SectionHeader('缓存 QA Seed')
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.CacheQaSeedSection()
          }
        }

        ListItem() {
          this.SectionHeader('本地数据')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

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
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '离线缓存',
        subtitle: this.cacheSubtitle(),
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '刷新缓存状态',
        showChevron: false,
        action: () => {
          this.loadCacheStats()
        }
      })

      this.SettingsDivider()

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

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 大列表文件缓存',
        showChevron: false,
        action: () => {
          this.runSeedAction('large', () => CacheDeviceQaSeed.seedLargeFileBackedList(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 混合行缓存',
        showChevron: false,
        action: () => {
          this.runSeedAction('mixed', () => CacheDeviceQaSeed.seedMixedInlineFile(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 非法路径行',
        showChevron: false,
        action: () => {
          this.runSeedAction('invalid', () => CacheDeviceQaSeed.seedInvalidPathRow(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 孤立文件',
        showChevron: false,
        action: () => {
          this.runSeedAction('orphan', () => CacheDeviceQaSeed.seedOrphanPayloadFile(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 缺失文件行',
        showChevron: false,
        action: () => {
          this.runSeedAction('missing', () => CacheDeviceQaSeed.seedMissingFileRow(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed Hash 不匹配行',
        showChevron: false,
        action: () => {
          this.runSeedAction('hash', () => CacheDeviceQaSeed.seedHashMismatchRow(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '验证 Hash 修复',
        showChevron: false,
        action: () => {
          this.runSeedAction('hash-read', () => CacheDeviceQaSeed.validateHashMismatchRepair(this.hostContext()))
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: 'Seed 过期行',
        showChevron: false,
        action: () => {
          this.runSeedAction('expired', () => CacheDeviceQaSeed.seedExpiredRow(this.hostContext()))
        }
      })

      this.SettingsDivider()

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

  private cacheSubtitle(): string {
    let text = `列表 ${this.cacheStats.topicListCount} 组 · 详情 ${this.cacheStats.topicDetailCount} 篇`
    if (this.cacheStats.updatedAt > 0) {
      text += ` · 更新于 ${DateUtils.toDateString(this.cacheStats.updatedAt)}`
    }
    return text
  }

  private loadCacheStats(): void {
    const context = this.hostContext()
    CacheSettings.loadStats(context)
      .then((stats: CacheStats) => {
        this.cacheStats = stats
      })
      .catch((error: Error) => {
        this.cacheMessage = error.message || '读取缓存状态失败'
        console.error('load cache stats failed: ' + error.message)
      })
  }

  private confirmClearCache(): void {
    AlertDialog.show({
      title: '清理缓存',
      message: '将只清理离线缓存，不会清理登录状态或偏好设置。确定继续吗？',
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '清理',
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
        this.cacheMessage = '已清理'
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.cacheMessage = error.message || '清理失败'
      })
  }

  private confirmClearLocalData(): void {
    AlertDialog.show({
      title: '清理本地数据',
      message: '将清理本机保存的稍后读、关注节点、最近浏览、已读状态、草稿、搜索历史、通知缓存和离线缓存。登录状态与偏好设置会保留。确定继续吗？',
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '清理',
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
        this.cacheMessage = '已清理'
        this.localDataMessage = '已清理'
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.localDataMessage = error.message || '清理失败'
      })
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private runSeedAll(): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = '仅 debug 构建可用'
      return
    }
    CacheDeviceQaSeed.seedAll(this.hostContext())
      .then((results: CacheDeviceQaSeedResult[]) => {
        const rows = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededRows, 0)
        const files = results.reduce((sum: number, result: CacheDeviceQaSeedResult) => sum + result.seededFiles, 0)
        this.seedMessage = `已写入 ${rows} 行 / ${files} 文件`
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = error.message || 'Seed 失败'
      })
  }

  private runSeedAction(label: string, action: () => Promise<CacheDeviceQaSeedResult>): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = '仅 debug 构建可用'
      return
    }
    action()
      .then((result: CacheDeviceQaSeedResult) => {
        this.seedMessage = `${label}: ${result.seededRows} 行 / ${result.seededFiles} 文件`
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = error.message || 'Seed 失败'
      })
  }
}
