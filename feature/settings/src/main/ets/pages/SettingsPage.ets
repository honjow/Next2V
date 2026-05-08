import { common } from '@kit.AbilityKit'
import {
  AppTextField,
  ApiConstants,
  ApiDomainSettings,
  CacheSettings,
  type CacheStats,
  CookieJarSettings,
  DateUtils,
  FeedTabSettings,
  GroupedListSection,
  HttpClient,
  LocalDataSettings,
  MediaSettings,
  ReadingSettings,
  ConciseListRow,
  FilterChip,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ListDivider as SharedListDivider,
  StorageKeys,
  ThemeConstants,
  WriteActionSettings
} from 'shared'
import type { TabItem } from 'shared'
import { promptAction } from '@kit.ArkUI'

@Component
export struct SettingsPage {
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) onlyLoadImagesOnWifi: boolean = false
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD
  @StorageLink(StorageKeys.FEED_TAB_KEYS) feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) accountWriteEnabled: boolean = false
  @State private nodeTabName: string = ''
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
  @State private localDataMessage: string = ''
  private http: HttpClient = HttpClient.getInstance()

  aboutToAppear(): void {
    this.loadCacheStats()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() { this.SectionHeader('账号') }
        ListItem() { this.AccountSection() }

        ListItem() { this.SectionHeader('阅读') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.ReadingSection() }

        ListItem() { this.SectionHeader('首页') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.HomeSection() }

        ListItem() { this.SectionHeader('内容与媒体') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.MediaSection() }

        ListItem() { this.SectionHeader('通知') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.NotificationSection() }

        ListItem() { this.SectionHeader('写作') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.WritingSection() }

        ListItem() { this.SectionHeader('存储') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.CacheSection() }

        ListItem() { this.SectionHeader('高级') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.AdvancedSection() }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder SettingsDivider() {
    SharedListDivider()
  }

  @Builder AccountSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '账号管理',
        subtitle: '登录、签到、收藏和屏蔽列表',
        action: () => {
          this.stack.pushPathByName('Account', null)
        }
      })
    }
  }

  @Builder ReadingSection() {
    GroupedListSection() {
      this.ReadingPreferenceRows()

      this.SettingsDivider()

      ConciseListRow({
        title: '回复排序',
        subtitle: '按 V2EX 默认顺序',
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '只看楼主',
        subtitle: '主题详情内手动切换',
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '代码换行',
        subtitle: '跟随 Markdown 渲染器',
        showChevron: false
      })
    }
  }

  @Builder MediaSection() {
    GroupedListSection() {
      this.TogglePreferenceRow('图片自动加载', this.autoLoadImages, (value: boolean) => {
        this.updateAutoLoadImages(value)
      })

      this.SettingsDivider()

      this.TogglePreferenceRow('仅 Wi-Fi 加载图片', this.onlyLoadImagesOnWifi, (value: boolean) => {
        this.updateOnlyLoadImagesOnWifi(value)
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '图片主机识别',
        subtitle: '已启用保守识别',
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '链接打开',
        subtitle: '外部浏览器为主',
        showChevron: false
      })
    }
  }

  @Builder HomeSection() {
    GroupedListSection() {
      ForEach(FeedTabSettings.tabsFromKeysJson(this.feedTabKeys), (tab: TabItem, index: number) => {
        this.HomeVisibleTabRow(tab, index, FeedTabSettings.tabsFromKeysJson(this.feedTabKeys).length)
        if (index < FeedTabSettings.tabsFromKeysJson(this.feedTabKeys).length - 1) {
          this.SettingsDivider()
        }
      }, (tab: TabItem) => tab.key)

      this.SettingsDivider()

      ForEach(ApiConstants.TAB_ITEMS.filter((tab: TabItem) => !FeedTabSettings.isVisible(this.feedTabKeys, tab.key)), (tab: TabItem) => {
        ConciseListRow({
          title: `添加 ${tab.label}`,
          showChevron: false,
          action: () => { this.updateFeedTabVisibility(tab.key, true) }
        })
        this.SettingsDivider()
      }, (tab: TabItem) => tab.key)

      Column({ space: ThemeConstants.SPACE_SM }) {
        AppTextField({
          text: $nodeTabName,
          placeholder: '节点名（如 create）',
          onTextChange: (value: string) => { this.nodeTabName = value }
        })
        Button('添加节点栏目')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(Color.White)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .width('100%')
          .onClick(() => { this.addNodeFeedTab() })
      }
      .padding(ThemeConstants.SPACE_LG)

      this.SettingsDivider()

      ConciseListRow({
        title: '恢复默认栏目',
        showChevron: false,
        action: () => { this.resetFeedTabs() }
      })
    }
  }

  @Builder HomeVisibleTabRow(tab: TabItem, index: number, count: number) {
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

      this.HomeTabButton('↑', index > 0, () => { this.moveFeedTab(tab.key, -1) })
      this.HomeTabButton('↓', index < count - 1, () => { this.moveFeedTab(tab.key, 1) })
      this.HomeTabButton(FeedTabSettings.isNodeKey(tab.key) ? '删' : '隐', count > 1, () => {
        this.updateFeedTabVisibility(tab.key, false)
      })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder HomeTabButton(label: string, enabled: boolean, action: () => void) {
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

  @Builder NotificationSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '通知同步',
        subtitle: '打开通知页时刷新',
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '本地通知',
        subtitle: '未开启系统推送',
        showChevron: false
      })

      this.SettingsDivider()

      ConciseListRow({
        title: '安静时段',
        subtitle: '未配置',
        showChevron: false
      })
    }
  }

  @Builder WritingSection() {
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

  @Builder AdvancedSection() {
    GroupedListSection() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        ConciseListRow({
          title: 'API 域名',
          subtitle: `当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`,
          showChevron: false
        })

        Row({ space: ThemeConstants.SPACE_SM }) {
          FilterChip({
            label: 'v2ex.com',
            selected: !this.useCoDomain,
            fill: true,
            action: () => { this.updateApiDomain(false) }
          })
          FilterChip({
            label: 'v2ex.co',
            selected: this.useCoDomain,
            fill: true,
            action: () => { this.updateApiDomain(true) }
          })
        }
        .width('100%')
        .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
      }
      .width('100%')
    }
  }

  @Builder TogglePreferenceRow(title: string, checked: boolean, changeAction: (value: boolean) => void) {
    ConciseListRow({ title: title, showChevron: false, hasSwitch: true, checked: checked, switchAction: changeAction })
  }

  @Builder ReadingPreferenceRows() {
    Column() {
      ConciseListRow({
        title: '阅读显示',
        subtitle: `${this.readingFontSize}fp / ${this.readingLineHeight}vp · ${this.readingDensityText(this.readingDensity)}`,
        showChevron: false
      })

      this.SettingsDivider()

      this.StepperPreferenceRow('字号', `${this.readingFontSize}fp`, 'A-', 'A+', () => {
        this.updateReadingFontSize(this.readingFontSize - 1)
      }, () => {
        this.updateReadingFontSize(this.readingFontSize + 1)
      }, () => {
        this.updateReadingFontSize(ThemeConstants.FONT_SIZE_BODY)
      })

      this.SettingsDivider()

      this.StepperPreferenceRow('行距', `${this.readingLineHeight}vp`, '-', '+', () => {
        this.updateReadingLineHeight(this.readingLineHeight - 1)
      }, () => {
        this.updateReadingLineHeight(this.readingLineHeight + 1)
      }, () => {
        this.updateReadingLineHeight(ThemeConstants.LINE_HEIGHT_BODY)
      })

      this.SettingsDivider()

      Row({ space: ThemeConstants.SPACE_SM }) {
        Text('密度')
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        this.DensityChip('紧凑', ReadingSettings.DENSITY_COMPACT)
        this.DensityChip('标准', ReadingSettings.DENSITY_STANDARD)
        this.DensityChip('宽松', ReadingSettings.DENSITY_COMFORTABLE)
      }
      .width('100%')
      .height(52)
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
    }
    .width('100%')
  }

  @Builder StepperPreferenceRow(
    title: string,
    value: string,
    decreaseLabel: string,
    increaseLabel: string,
    decreaseAction: () => void,
    increaseAction: () => void,
    resetAction: () => void
  ) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(title)
        .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      this.CompactSettingButton(decreaseLabel, decreaseAction)
      this.CompactSettingButton('默认', resetAction)
      this.CompactSettingButton(increaseLabel, increaseAction)
    }
    .width('100%')
    .height(52)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }

  @Builder CompactSettingButton(label: string, action: () => void) {
    Button(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .height(30)
      .constraintSize({ minWidth: 36 })
      .type(ButtonType.Normal)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .fontColor($r('sys.color.font_primary'))
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(action)
  }

  @Builder DensityChip(label: string, density: string) {
    FilterChip({
      label,
      selected: this.readingDensity === density,
      fill: true,
      action: () => { this.updateReadingDensity(density) }
    })
  }

  @Builder CacheSection() {
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
          .onClick(() => { this.loadCacheStats() })
        Button('清理缓存')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.clearCache() })
      }
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_MD })

      this.SettingsDivider()

      Column() {
        ConciseListRow({
          title: '清理本地数据',
          primaryColor: Color.Red,
          subtitle: this.localDataMessage,
          showChevron: false,
          action: () => { this.confirmClearLocalData() }
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
    this.saveReadingSettings(this.readingFontSize, ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize), this.readingDensity)
  }

  private updateReadingDensity(density: string): void {
    this.saveReadingSettings(this.readingFontSize, this.readingLineHeight, density)
  }

  private saveReadingSettings(fontSize: number, lineHeight: number, density: string): void {
    this.readingFontSize = ReadingSettings.normalizeFontSize(fontSize)
    this.readingLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize)
    this.readingDensity = ReadingSettings.normalizeDensity(density)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.save(context, this.readingFontSize, this.readingLineHeight, this.readingDensity).catch((error: Error) => {
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
      promptAction.openToast({ message: '请输入有效节点名' }).catch((_error: Error) => { })
      return
    }
    const nextKeys = FeedTabSettings.addNode(this.feedTabKeys, cleanName)
    if (nextKeys === this.feedTabKeys) {
      promptAction.openToast({ message: '节点栏目已存在' }).catch((_error: Error) => { })
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
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '开启',
        fontColor: ThemeConstants.BRAND_PRIMARY,
        action: () => { this.updateWriteActions(true) }
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
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '清理',
        fontColor: Color.Red,
        action: () => { this.clearLocalData() }
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
