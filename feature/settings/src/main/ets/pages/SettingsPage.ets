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
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  WriteActionSettings
} from 'shared'

@Component
export struct SettingsPage {
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) onlyLoadImagesOnWifi: boolean = false
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

        ListItem() { this.SectionHeader('关于') }
          .margin({ top: ThemeConstants.SPACE_MD })
        ListItem() { this.AboutSection() }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: ThemeConstants.SPACE_XS })
      .width('100%')
  }

  @Builder SettingsDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ left: ThemeConstants.SPACE_LG })
  }

  @Builder NetworkSection() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('API 域名')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

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
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder PreferenceSection() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('图片自动加载')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.autoLoadImages ? '进入帖子时直接加载图片' : '仅保留图片占位与预览入口')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.autoLoadImages })
          .onChange((value: boolean) => { this.updateAutoLoadImages(value) })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)

      this.SettingsDivider()

      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('仅 Wi-Fi 加载图片')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.onlyLoadImagesOnWifi ? '蜂窝网络下保留图片占位' : '任意网络都自动加载图片')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.onlyLoadImagesOnWifi })
          .onChange((value: boolean) => { this.updateOnlyLoadImagesOnWifi(value) })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)

      this.SettingsDivider()

      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('写入操作')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.accountWriteEnabled ? '已开启，提交仍需二次确认' : '关闭，发帖/回复仅保存草稿')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.accountWriteEnabled })
          .onChange((value: boolean) => {
            if (value) {
              this.confirmEnableWriteActions()
            } else {
              this.updateWriteActions(false)
            }
          })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder CacheSection() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('离线缓存')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`列表 ${this.cacheStats.topicListCount} 组 · 详情 ${this.cacheStats.topicDetailCount} 篇`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
          if (this.cacheStats.updatedAt > 0) {
            Text(`更新于 ${DateUtils.toDateString(this.cacheStats.updatedAt)}`)
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
          }
          if (this.cacheMessage) {
            Text(this.cacheMessage)
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.cacheStats.topicListCount + this.cacheStats.topicDetailCount}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })

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

      Row({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('本地数据')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('稍后读 / 关注节点 / 最近浏览 / 草稿 / 搜索历史')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.localDataMessage) {
            Text(this.localDataMessage)
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button('清理本地数据')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(Color.Red)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => { this.confirmClearLocalData() })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_LG })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder AboutSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text('Next2V')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text('版本 0.1.0')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      Text('基于 ArkTS + ArkUI + HDS 构建的 V2EX 客户端')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
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
