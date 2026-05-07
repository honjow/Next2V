import { common } from '@kit.AbilityKit'
import {
  ApiConstants,
  ApiDomainSettings,
  CacheSettings,
  type CacheStats,
  CookieJarSettings,
  DateUtils,
  HttpClient,
  LocalDataSettings,
  MediaSettings,
  ReadingSettings,
  ConciseListRow,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ListDivider as SharedListDivider,
  StorageKeys,
  ThemeConstants,
  WriteActionSettings
} from 'shared'

@Component
export struct SettingsPage {
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) onlyLoadImagesOnWifi: boolean = false
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) accountWriteEnabled: boolean = false
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
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
        ListItem() { this.SectionHeader('网络') }
        ListItem() { this.NetworkSection() }

        ListItem() { this.SectionHeader('偏好') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.PreferenceSection() }

        ListItem() { this.SectionHeader('存储') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.CacheSection() }
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

  @Builder NetworkSection() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      ConciseListRow({
        title: 'API 域名',
        subtitle: `当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`,
        showChevron: false
      })

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('v2ex.com')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(!this.useCoDomain ? Color.White : $r('sys.color.font_primary'))
          .backgroundColor(!this.useCoDomain ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateApiDomain(false) })
        Button('v2ex.co')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(this.useCoDomain ? Color.White : $r('sys.color.font_primary'))
          .backgroundColor(this.useCoDomain ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateApiDomain(true) })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .padding(4)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder PreferenceSection() {
    Column() {
      this.TogglePreferenceRow('图片自动加载', this.autoLoadImages, (value: boolean) => {
        this.updateAutoLoadImages(value)
      })

      this.SettingsDivider()

      this.TogglePreferenceRow('仅 Wi-Fi 加载图片', this.onlyLoadImagesOnWifi, (value: boolean) => {
        this.updateOnlyLoadImagesOnWifi(value)
      })

      this.SettingsDivider()

      this.ReadingPreferenceRows()

      this.SettingsDivider()

      this.TogglePreferenceRow('写入操作', this.accountWriteEnabled, (value: boolean) => {
        if (value) {
          this.confirmEnableWriteActions()
        } else {
          this.updateWriteActions(false)
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .padding(4)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder TogglePreferenceRow(title: string, checked: boolean, changeAction: (value: boolean) => void) {
    ConciseListRow({ title: title, showChevron: false, hasSwitch: true, checked: checked, switchAction: changeAction })
  }

  @Builder ReadingPreferenceRows() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      ConciseListRow({
        title: '阅读显示',
        subtitle: `${this.readingFontSize}fp / ${this.readingLineHeight}vp · ${this.readingDensityText(this.readingDensity)}`,
        showChevron: false
      })

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('A-')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingFontSize(this.readingFontSize - 1) })
        Button('默认字号')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingFontSize(ThemeConstants.FONT_SIZE_BODY) })
        Button('A+')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingFontSize(this.readingFontSize + 1) })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('行距-')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingLineHeight(this.readingLineHeight - 1) })
        Button('默认行距')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingLineHeight(ThemeConstants.LINE_HEIGHT_BODY) })
        Button('行距+')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .onClick(() => { this.updateReadingLineHeight(this.readingLineHeight + 1) })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })

      Row({ space: ThemeConstants.SPACE_SM }) {
        this.DensityButton('紧凑', ReadingSettings.DENSITY_COMPACT)
        this.DensityButton('标准', ReadingSettings.DENSITY_STANDARD)
        this.DensityButton('宽松', ReadingSettings.DENSITY_COMFORTABLE)
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    }
    .width('100%')
  }

  @Builder DensityButton(label: string, density: string) {
    Button(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .height(ThemeConstants.TOUCH_TARGET_SM)
      .type(ButtonType.Normal)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .fontColor(this.readingDensity === density ? Color.White : $r('sys.color.font_primary'))
      .backgroundColor(this.readingDensity === density ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
      .layoutWeight(1)
      .onClick(() => { this.updateReadingDensity(density) })
  }

  @Builder CacheSection() {
    Column() {
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .padding(4)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
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
