import { common } from '@kit.AbilityKit'
import type { TabItem } from 'shared'
import {
  ApiConstants,
  ApiDomainSettings,
  AppTextField,
  CacheSettings,
  ConciseListRow,
  CookieJarSettings,
  DateUtils,
  FeedTabSettings,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  LocalDataSettings,
  MediaSettings,
  ReadingSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  ThemeConstants,
  ThemeSettings,
  type CacheStats,
  WriteActionSettings
} from 'shared'
import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct SettingsPage {
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) onlyLoadImagesOnWifi: boolean = false
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD
  @StorageLink(StorageKeys.THEME_MODE) themeMode: string = ThemeSettings.MODE_AUTO
  @StorageLink(StorageKeys.FEED_TAB_KEYS) feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) accountWriteEnabled: boolean = false
  @State private nodeTabName: string = ''
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
  @State private localDataMessage: string = ''
  @State private themeMenuShown: boolean = false
  @State private apiDomainMenuShown: boolean = false
  @State private densityMenuShown: boolean = false
  private http: HttpClient = HttpClient.getInstance()

  aboutToAppear(): void {
    this.loadCacheStats()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.SectionHeader('账号')
        }

        ListItem() {
          this.AccountSection()
        }

        ListItem() {
          this.SectionHeader('阅读')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.ReadingSection()
        }

        ListItem() {
          this.SectionHeader('首页')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.HomeSection()
        }

        ListItem() {
          this.SectionHeader('内容与媒体')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.MediaSection()
        }

        ListItem() {
          this.SectionHeader('写作')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.WritingSection()
        }

        ListItem() {
          this.SectionHeader('存储')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.CacheSection()
        }

        ListItem() {
          this.SectionHeader('高级')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AdvancedSection()
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
  AccountSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '账号管理',
        action: () => {
          this.stack.pushPathByName('Account', null)
        }
      })
    }
  }

  @Builder
  ReadingSection() {
    GroupedListSection() {
      this.ReadingPreferenceRows()
    }
  }

  @Builder
  MediaSection() {
    GroupedListSection() {
      this.TogglePreferenceRow('图片自动加载', this.autoLoadImages, (value: boolean) => {
        this.updateAutoLoadImages(value)
      })

      this.SettingsDivider()

      this.TogglePreferenceRow('仅 Wi-Fi 加载图片', this.onlyLoadImagesOnWifi, (value: boolean) => {
        this.updateOnlyLoadImagesOnWifi(value)
      }, this.autoLoadImages)
    }
  }

  @Builder
  HomeSection() {
    GroupedListSection() {
      ForEach(FeedTabSettings.tabsFromKeysJson(this.feedTabKeys), (tab: TabItem, index: number) => {
        this.HomeVisibleTabRow(tab, index, FeedTabSettings.tabsFromKeysJson(this.feedTabKeys).length)
        if (index < FeedTabSettings.tabsFromKeysJson(this.feedTabKeys).length - 1) {
          this.SettingsDivider()
        }
      }, (tab: TabItem) => tab.key)

      this.SettingsDivider()

      ForEach(ApiConstants.TAB_ITEMS.filter((tab: TabItem) => !FeedTabSettings.isVisible(this.feedTabKeys, tab.key)),
        (tab: TabItem) => {
          ConciseListRow({
            title: `添加 ${tab.label}`,
            showChevron: false,
            action: () => {
              this.updateFeedTabVisibility(tab.key, true)
            }
          })
          this.SettingsDivider()
        }, (tab: TabItem) => tab.key)

      Column({ space: ThemeConstants.SPACE_SM }) {
        AppTextField({
          text: $nodeTabName,
          placeholder: '节点名（如 create）',
          onTextChange: (value: string) => {
            this.nodeTabName = value
          }
        })
          .width('100%')
        Button('添加节点栏目')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(Color.White)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .width('100%')
          .onClick(() => {
            this.addNodeFeedTab()
          })
      }
      .padding(ThemeConstants.SPACE_LG)

      this.SettingsDivider()

      ConciseListRow({
        title: '恢复默认栏目',
        showChevron: false,
        action: () => {
          this.resetFeedTabs()
        }
      })
    }
  }

  @Builder
  HomeVisibleTabRow(tab: TabItem, index: number, count: number) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(tab.label)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(FeedTabSettings.isNodeKey(tab.key) ? '节点栏目' : '首页栏目')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.HomeTabButton('↑', index > 0, () => {
        this.moveFeedTab(tab.key, -1)
      })
      this.HomeTabButton('↓', index < count - 1, () => {
        this.moveFeedTab(tab.key, 1)
      })
      this.HomeTabButton(FeedTabSettings.isNodeKey(tab.key) ? '删' : '隐', count > 1, () => {
        this.updateFeedTabVisibility(tab.key, false)
      })
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  HomeTabButton(label: string, enabled: boolean, action: () => void) {
    Button(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .height(ThemeConstants.TOUCH_TARGET_SM)
      .width(48)
      .enabled(enabled)
      .type(ButtonType.Normal)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .fontColor(enabled ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(action)
  }

  @Builder
  WritingSection() {
    GroupedListSection() {
      this.TogglePreferenceRow('写入操作', this.accountWriteEnabled, (value: boolean) => {
        if (value) {
          this.confirmEnableWriteActions()
        } else {
          this.updateWriteActions(false)
        }
      })
    }
  }

  @Builder
  AdvancedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: 'API 域名',
        trailingText: this.useCoDomain ? 'v2ex.co' : 'v2ex.com',
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showApiDomainMenu()
        }
      })
        .bindMenu(this.apiDomainMenuShown, this.ApiDomainMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.apiDomainMenuShown = false
          }
        })
    }
  }

  @Builder
  TogglePreferenceRow(title: string, checked: boolean, changeAction: (value: boolean) => void, isEnabled: boolean = true) {
    ConciseListRow({
      title: title,
      showChevron: false,
      hasSwitch: true,
      checked: checked,
      isEnabled: isEnabled,
      switchAction: changeAction
    })
  }

  @Builder
  ReadingPreferenceRows() {
    Column() {
      ConciseListRow({
        title: '主题',
        trailingText: ThemeSettings.modeText(this.themeMode),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showThemeMenu()
        }
      })
        .bindMenu(this.themeMenuShown, this.ThemeModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.themeMenuShown = false
          }
        })

      this.SettingsDivider()

      ConciseListRow({
        title: '字号',
        showChevron: false,
        hasCounter: true,
        counterValue: `${this.readingFontSize}fp`,
        counterDecreaseEnabled: this.readingFontSize > ReadingSettings.FONT_SIZE_MIN,
        counterIncreaseEnabled: this.readingFontSize < ReadingSettings.FONT_SIZE_MAX,
        counterDecreaseAction: () => {
          this.updateReadingFontSize(this.readingFontSize - 1)
        },
        counterIncreaseAction: () => {
          this.updateReadingFontSize(this.readingFontSize + 1)
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '行距',
        showChevron: false,
        hasCounter: true,
        counterValue: `${this.readingLineHeight}vp`,
        counterDecreaseEnabled: this.readingLineHeight > this.readingLineHeightMin(),
        counterIncreaseEnabled: this.readingLineHeight < ReadingSettings.LINE_HEIGHT_MAX,
        counterDecreaseAction: () => {
          this.updateReadingLineHeight(this.readingLineHeight - 1)
        },
        counterIncreaseAction: () => {
          this.updateReadingLineHeight(this.readingLineHeight + 1)
        }
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '密度',
        trailingText: this.readingDensityText(this.readingDensity),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showDensityMenu()
        }
      })
        .bindMenu(this.densityMenuShown, this.ReadingDensityMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.densityMenuShown = false
          }
        })

      this.SettingsDivider()

      ConciseListRow({
        title: '恢复默认阅读设置',
        showChevron: false,
        action: () => {
          this.confirmResetReadingSettings()
        }
      })
    }
    .width('100%')
  }

  @Builder
  ThemeModeMenu() {
    Menu() {
      this.ThemeModeMenuItem('自动', ThemeSettings.MODE_AUTO)
      this.ThemeModeMenuItem('浅色', ThemeSettings.MODE_LIGHT)
      this.ThemeModeMenuItem('深色', ThemeSettings.MODE_DARK)
    }
  }

  @Builder
  ReadingDensityMenu() {
    Menu() {
      this.ReadingDensityMenuItem('紧凑', ReadingSettings.DENSITY_COMPACT)
      this.ReadingDensityMenuItem('标准', ReadingSettings.DENSITY_STANDARD)
      this.ReadingDensityMenuItem('宽松', ReadingSettings.DENSITY_COMFORTABLE)
    }
  }

  @Builder
  ApiDomainMenu() {
    Menu() {
      this.ApiDomainMenuItem('v2ex.com', false)
      this.ApiDomainMenuItem('v2ex.co', true)
    }
  }

  @Builder
  ApiDomainMenuItem(label: string, useCoDomain: boolean) {
    MenuItem({
      content: label,
      symbolEndIcon: this.useCoDomain === useCoDomain ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    })
      .onClick(() => {
        this.updateApiDomain(useCoDomain)
      })
  }

  @Builder
  ReadingDensityMenuItem(label: string, density: string) {
    MenuItem({
      content: label,
      symbolEndIcon: this.readingDensity === density ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    })
      .onClick(() => {
        this.updateReadingDensity(density)
      })
  }

  @Builder
  ThemeModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon: this.themeMode === mode ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    })
      .onClick(() => {
        this.updateThemeMode(mode)
      })
  }

  private showThemeMenu(): void {
    this.themeMenuShown = false
    setTimeout(() => {
      this.themeMenuShown = true
    }, 20)
  }

  private showApiDomainMenu(): void {
    this.apiDomainMenuShown = false
    setTimeout(() => {
      this.apiDomainMenuShown = true
    }, 20)
  }

  private showDensityMenu(): void {
    this.densityMenuShown = false
    setTimeout(() => {
      this.densityMenuShown = true
    }, 20)
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '离线缓存',
        subtitle: this.cacheSubtitle(),
        count: this.cacheStats.topicListCount + this.cacheStats.topicDetailCount,
        showChevron: false
      })

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('刷新状态')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => {
            this.loadCacheStats()
          })
        Button('清理缓存')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => {
            this.clearCache()
          })
      }
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_MD })

      this.SettingsDivider()

      Column() {
        ConciseListRow({
          title: '清理本地数据',
          primaryColor: Color.Red,
          subtitle: this.localDataMessage,
          showChevron: false,
          action: () => {
            this.confirmClearLocalData()
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private updateApiDomain(useCoDomain: boolean): void {
    this.useCoDomain = useCoDomain
    this.http.setBaseUrl(useCoDomain ? ApiConstants.BASE_URL_CO : ApiConstants.BASE_URL_COM)
    CookieJarSettings.refreshConfiguredState()
    CookieJarSettings.restoreCurrentToWebCookieManager().catch((error: Error) => {
      console.error('restore web cookie failed: ' + error.message)
    })
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.save(context, useCoDomain).catch((error: Error) => {
      console.error('save api domain failed: ' + error.message)
    })
  }

  private updateAutoLoadImages(autoLoadImages: boolean): void {
    this.autoLoadImages = autoLoadImages
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    MediaSettings.save(context, autoLoadImages, this.onlyLoadImagesOnWifi).catch((error: Error) => {
      console.error('save media settings failed: ' + error.message)
    })
  }

  private updateOnlyLoadImagesOnWifi(onlyLoadImagesOnWifi: boolean): void {
    if (!this.autoLoadImages) {
      return
    }
    this.onlyLoadImagesOnWifi = onlyLoadImagesOnWifi
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    MediaSettings.save(context, this.autoLoadImages, onlyLoadImagesOnWifi).catch((error: Error) => {
      console.error('save media settings failed: ' + error.message)
    })
  }

  private updateReadingFontSize(fontSize: number): void {
    const nextFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const nextLineHeight = ReadingSettings.normalizeLineHeight(this.readingLineHeight, nextFontSize)
    this.saveReadingSettings(nextFontSize, nextLineHeight, this.readingDensity)
  }

  private updateReadingLineHeight(lineHeight: number): void {
    this.saveReadingSettings(this.readingFontSize,
      ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize), this.readingDensity)
  }

  private updateReadingDensity(density: string): void {
    this.saveReadingSettings(this.readingFontSize, this.readingLineHeight, density)
  }

  private readingLineHeightMin(): number {
    return Math.max(ReadingSettings.LINE_HEIGHT_MIN, ReadingSettings.normalizeFontSize(this.readingFontSize) + 4)
  }

  private confirmResetReadingSettings(): void {
    AlertDialog.show({
      title: '恢复默认阅读设置',
      message: '将字号和行距恢复为默认值。确定继续吗？',
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '恢复',
        fontColor: ThemeConstants.BRAND_PRIMARY,
        action: () => {
          this.resetReadingSettings()
        }
      }
    })
  }

  private resetReadingSettings(): void {
    this.saveReadingSettings(ThemeConstants.FONT_SIZE_BODY, ThemeConstants.LINE_HEIGHT_BODY,
      this.readingDensity)
  }

  private updateThemeMode(mode: string): void {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    this.themeMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ThemeSettings.save(context, normalizedMode).catch((error: Error) => {
      console.error('save theme settings failed: ' + error.message)
    })
  }

  private saveReadingSettings(fontSize: number, lineHeight: number, density: string): void {
    this.readingFontSize = ReadingSettings.normalizeFontSize(fontSize)
    this.readingLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize)
    this.readingDensity = ReadingSettings.normalizeDensity(density)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.save(context, this.readingFontSize, this.readingLineHeight, this.readingDensity)
      .catch((error: Error) => {
        console.error('save reading settings failed: ' + error.message)
      })
  }

  private updateFeedTabVisibility(key: string, _visible: boolean): void {
    const nextKeys = FeedTabSettings.toggleKey(this.feedTabKeys, key)
    if (nextKeys === this.feedTabKeys) {
      return
    }
    this.saveFeedTabs(nextKeys)
  }

  private moveFeedTab(key: string, direction: number): void {
    const nextKeys = FeedTabSettings.moveKey(this.feedTabKeys, key, direction)
    if (nextKeys === this.feedTabKeys) {
      return
    }
    this.saveFeedTabs(nextKeys)
  }

  private addNodeFeedTab(): void {
    const cleanName = FeedTabSettings.normalizeNodeName(this.nodeTabName)
    if (!cleanName) {
      promptAction.openToast({ message: '请输入有效节点名' }).catch((_error: Error) => {
      })
      return
    }
    const nextKeys = FeedTabSettings.addNode(this.feedTabKeys, cleanName)
    if (nextKeys === this.feedTabKeys) {
      promptAction.openToast({ message: '节点栏目已存在' }).catch((_error: Error) => {
      })
      return
    }
    this.nodeTabName = ''
    this.saveFeedTabs(nextKeys)
  }

  private resetFeedTabs(): void {
    if (FeedTabSettings.isDefault(this.feedTabKeys)) {
      return
    }
    this.saveFeedTabs(FeedTabSettings.defaultKeysJson())
  }

  private saveFeedTabs(keysJson: string): void {
    this.feedTabKeys = keysJson
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    FeedTabSettings.save(context, keysJson).catch((error: Error) => {
      console.error('save feed tab settings failed: ' + error.message)
    })
  }

  private readingDensityText(density: string): string {
    if (density === ReadingSettings.DENSITY_COMPACT) {
      return '紧凑'
    }
    if (density === ReadingSettings.DENSITY_COMFORTABLE) {
      return '宽松'
    }
    return '标准'
  }

  private cacheSubtitle(): string {
    let text = `列表 ${this.cacheStats.topicListCount} 组 · 详情 ${this.cacheStats.topicDetailCount} 篇`
    if (this.cacheStats.updatedAt > 0) {
      text += ` · 更新于 ${DateUtils.toDateString(this.cacheStats.updatedAt)}`
    }
    if (this.cacheMessage) {
      text += ` · ${this.cacheMessage}`
    }
    return text
  }

  private confirmEnableWriteActions(): void {
    if (this.accountWriteEnabled) {
      return
    }
    AlertDialog.show({
      title: '开启写入操作',
      message: '写入操作可能导致误触或误操作。确定开启吗？',
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '开启',
        fontColor: ThemeConstants.BRAND_PRIMARY,
        action: () => {
          this.updateWriteActions(true)
        }
      }
    })
  }

  private updateWriteActions(enabled: boolean): void {
    this.accountWriteEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    WriteActionSettings.save(context, enabled).catch((error: Error) => {
      console.error('save write settings failed: ' + error.message)
    })
  }

  private loadCacheStats(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CacheSettings.loadStats(context)
      .then((stats: CacheStats) => {
        this.cacheStats = stats
      })
      .catch((error: Error) => {
        console.error('load cache stats failed: ' + error.message)
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
