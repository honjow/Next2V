import { common } from '@kit.AbilityKit'
import {
  CacheSettings,
  ConciseListRow,
  DateUtils,
  GroupedListSection,
  ListDivider as SharedListDivider,
  LocalDataSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ThemeConstants,
  type CacheStats
} from 'shared'

@Component
export struct StorageSettingsPage {
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
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

  private cacheSubtitle(): string {
    let text = `列表 ${this.cacheStats.topicListCount} 组 · 详情 ${this.cacheStats.topicDetailCount} 篇`
    if (this.cacheStats.updatedAt > 0) {
      text += ` · 更新于 ${DateUtils.toDateString(this.cacheStats.updatedAt)}`
    }
    return text
  }

  private loadCacheStats(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
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
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
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
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
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
}
