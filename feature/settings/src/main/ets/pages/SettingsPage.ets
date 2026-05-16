import { common } from '@kit.AbilityKit'
import {
  ApiConstants,
  ApiDomainSettings,
  AutoDailyCheckinSettings,
  CacheSettings,
  ConciseListRow,
  CookieJarSettings,
  DateUtils,
  GroupedListSection,
  HttpClient,
  ListDivider as SharedListDivider,
  MediaSettings,
  ReadingSettings,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  ThemeConstants,
  ThemeSettings,
  ReplyActionAlignmentSettings,
  ReplyDisplaySettings,
  MotionHandStateService,
  ReplyCardStyleSettings,
  type CacheStats,
} from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'
@Component
export struct SettingsPage {
  @Consume('ns') stack: NavPathStack;
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false;
  @StorageLink(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED) autoDailyCheckinEnabled: boolean = true;
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true;
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) onlyLoadImagesOnWifi: boolean = false;
  @StorageLink(StorageKeys.THEME_MODE) themeMode: string = ThemeSettings.MODE_AUTO;
  @StorageLink(StorageKeys.REPLY_DISPLAY_MODE) replyDisplayMode: string =
    ReplyDisplaySettings.MODE_THREAD;
  @StorageLink(StorageKeys.REPLY_CARD_STYLE) replyCardStyle: string =
    ReplyCardStyleSettings.STYLE_STANDARD;
  @StorageLink(StorageKeys.REPLY_ACTION_ALIGNMENT_MODE) replyActionAlignmentMode: string =
    ReplyActionAlignmentSettings.MODE_UNSET;
  @StorageLink(StorageKeys.MOTION_HOLDING_HAND_SUPPORTED) motionHoldingHandSupported: boolean = false;
  @StorageLink(StorageKeys.READING_RESTORE_POSITION) readingRestorePosition: boolean = false;
  @StorageLink(StorageKeys.READING_BASE64_DECODE_MODE) base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE;
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 };
  @State private themeMenuShown: boolean = false;
  @State private replyDisplayMenuShown: boolean = false;
  @State private replyCardStyleMenuShown: boolean = false;
  @State private replyActionAlignmentMenuShown: boolean = false;
  @State private base64ModeMenuShown: boolean = false;
  @State private apiDomainMenuShown: boolean = false;
  private http: HttpClient = HttpClient.getInstance();

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
        ListItem() {
          this.ReadingSection()
        }
        ListItem() {
          this.SectionHeader('首页')
        }
        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: '首页栏目设置',
              action: () => {
                this.stack.pushPathByName('HomeNodeSettings', null)
              },
            })
          }
        }
        ListItem() {
          this.SectionHeader('内容与媒体')
        }
        ListItem() {
          this.MediaSection()
        }
        ListItem() {
          this.SectionHeader('存储')
        }
        ListItem() {
          this.CacheSection()
        }
        ListItem() {
          this.SectionHeader('高级')
        }
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
    SharedSectionHeader({ title: title }).margin({ top: ThemeConstants.SPACE_MD })
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
        },
      })
      this.SettingsDivider()
      this.TogglePreferenceRow('自动签到', this.autoDailyCheckinEnabled, (value: boolean) => {
        this.updateAutoDailyCheckin(value)
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

      if (this.autoLoadImages) {
        this.TogglePreferenceRow(
          '仅 Wi-Fi 加载图片',
          this.onlyLoadImagesOnWifi,
          (value: boolean) => {
            this.updateOnlyLoadImagesOnWifi(value)
          },
        )
      } else {
        this.DisabledWifiImagePreferenceRow()
      }
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
        },
      })
        .bindMenu(this.apiDomainMenuShown, this.ApiDomainMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.apiDomainMenuShown = false
          },
        })
    }
  }

  @Builder
  TogglePreferenceRow(
    title: string,
    checked: boolean,
    changeAction: (value: boolean) => void,
    isEnabled: boolean = true,
  ) {
    ConciseListRow({
      title: title,
      showChevron: false,
      hasSwitch: true,
      checked: checked,
      isEnabled: isEnabled,
      switchAction: changeAction,
    })
  }

  @Builder
  DisabledWifiImagePreferenceRow() {
    ConciseListRow({
      title: '仅 Wi-Fi 加载图片',
      showChevron: false,
      hasSwitch: true,
      checked: this.onlyLoadImagesOnWifi,
      isEnabled: false,
      switchAction: (_value: boolean) => {},
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
        },
      })
        .bindMenu(this.themeMenuShown, this.ThemeModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.themeMenuShown = false
          },
        })

      this.SettingsDivider()
      ConciseListRow({
        title: '回复显示',
        trailingText: ReplyDisplaySettings.modeText(this.replyDisplayMode),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showReplyDisplayMenu()
        },
      })
        .bindMenu(this.replyDisplayMenuShown, this.ReplyDisplayModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.replyDisplayMenuShown = false
          },
        })

      this.SettingsDivider()
      ConciseListRow({
        title: '回复样式',
        trailingText: ReplyCardStyleSettings.styleText(this.replyCardStyle),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showReplyCardStyleMenu()
        },
      })
        .bindMenu(this.replyCardStyleMenuShown, this.ReplyCardStyleMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.replyCardStyleMenuShown = false
          },
        })

      this.SettingsDivider()
      ConciseListRow({
        title: '回复按钮对齐方式',
        trailingText: ReplyActionAlignmentSettings.modeText(
          this.replyActionAlignmentMode,
          this.motionHoldingHandSupported,
        ),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showReplyActionAlignmentMenu()
        },
      })
        .bindMenu(this.replyActionAlignmentMenuShown, this.ReplyActionAlignmentMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.replyActionAlignmentMenuShown = false
          },
        })

      this.SettingsDivider()

      this.TogglePreferenceRow('记住阅读位置', this.readingRestorePosition, (value: boolean) => {
        this.updateRestorePosition(value)
      })

      this.SettingsDivider()
      ConciseListRow({
        title: 'Base64 解码',
        subtitle: '默认点击查看，避免直接暴露邮箱/微信等明文',
        trailingText: this.base64DecodeModeLabel(),
        showChevron: false,
        trailingDropdown: true,
        action: () => {
          this.showBase64ModeMenu()
        },
      })
        .bindMenu(this.base64ModeMenuShown, this.Base64ModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.base64ModeMenuShown = false
          },
        })

      this.SettingsDivider()
      ConciseListRow({
        title: '阅读字体设置',
        action: () => {
          this.stack.pushPathByName('ReadingSettings', null)
        },
      })
    }.width('100%')
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
  ReplyDisplayModeMenu() {
    Menu() {
      this.ReplyDisplayModeMenuItem('楼中楼', ReplyDisplaySettings.MODE_THREAD)
      this.ReplyDisplayModeMenuItem('楼中楼(@)', ReplyDisplaySettings.MODE_THREAD_WITH_MENTION)
      this.ReplyDisplayModeMenuItem('冗余楼中楼', ReplyDisplaySettings.MODE_THREAD_REDUNDANT)
      this.ReplyDisplayModeMenuItem('只看楼主', ReplyDisplaySettings.MODE_OP)
      this.ReplyDisplayModeMenuItem('原版', ReplyDisplaySettings.MODE_ORIGIN)
    }
  }

  @Builder
  ReplyCardStyleMenu() {
    Menu() {
      this.ReplyCardStyleMenuItem('标准', ReplyCardStyleSettings.STYLE_STANDARD)
      this.ReplyCardStyleMenuItem('紧凑', ReplyCardStyleSettings.STYLE_COMPACT)
    }
  }

  @Builder
  ReplyActionAlignmentMenu() {
    Menu() {
      if (this.motionHoldingHandSupported) {
        this.ReplyActionAlignmentMenuItem(
          '智感握姿',
          ReplyActionAlignmentSettings.MODE_SMART_GRIP,
        )
      }
      this.ReplyActionAlignmentMenuItem(
        '跟随操作',
        ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION,
      )
      this.ReplyActionAlignmentMenuItem('固定左侧', ReplyActionAlignmentSettings.MODE_FIXED_LEFT)
      this.ReplyActionAlignmentMenuItem('固定右侧', ReplyActionAlignmentSettings.MODE_FIXED_RIGHT)
    }
  }

  @Builder
  Base64ModeMenu() {
    Menu() {
      this.Base64ModeMenuItem('关闭', ReadingSettings.BASE64_MODE_OFF)
      this.Base64ModeMenuItem('点击查看', ReadingSettings.BASE64_MODE_BADGE)
      this.Base64ModeMenuItem('文内显示', ReadingSettings.BASE64_MODE_INLINE)
    }
  }

  @Builder
  Base64ModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.base64DecodeMode === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateBase64DecodeMode(mode)
    })
  }

  @Builder
  ReplyCardStyleMenuItem(label: string, style: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.replyCardStyle === style
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateReplyCardStyle(style)
    })
  }

  @Builder
  ReplyActionAlignmentMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        ReplyActionAlignmentSettings.effectiveMode(
          this.replyActionAlignmentMode,
          this.motionHoldingHandSupported,
        ) === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateReplyActionAlignmentMode(mode)
    })
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
      symbolEndIcon:
        this.useCoDomain === useCoDomain
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateApiDomain(useCoDomain)
    })
  }

  @Builder
  ThemeModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.themeMode === mode ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    }).onClick(() => {
      this.updateThemeMode(mode)
    })
  }

  @Builder
  ReplyDisplayModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.replyDisplayMode === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateReplyDisplayMode(mode)
    })
  }

  private showThemeMenu(): void {
    this.themeMenuShown = false
    setTimeout(() => {
      this.themeMenuShown = true
    }, 20)
  }

  private showReplyDisplayMenu(): void {
    this.replyDisplayMenuShown = false
    setTimeout(() => {
      this.replyDisplayMenuShown = true
    }, 20)
  }

  private showReplyCardStyleMenu(): void {
    this.replyCardStyleMenuShown = false
    setTimeout(() => {
      this.replyCardStyleMenuShown = true
    }, 20)
  }

  private showReplyActionAlignmentMenu(): void {
    this.replyActionAlignmentMenuShown = false
    setTimeout(() => {
      this.replyActionAlignmentMenuShown = true
    }, 20)
  }

  private showBase64ModeMenu(): void {
    this.base64ModeMenuShown = false
    setTimeout(() => {
      this.base64ModeMenuShown = true
    }, 20)
  }

  private showApiDomainMenu(): void {
    this.apiDomainMenuShown = false
    setTimeout(() => {
      this.apiDomainMenuShown = true
    }, 20)
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '存储',
        subtitle: this.cacheSubtitle(),
        count: this.cacheStats.topicListCount + this.cacheStats.topicDetailCount,
        action: () => {
          this.stack.pushPathByName('Storage', null)
        },
      })
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

  private updateAutoDailyCheckin(enabled: boolean): void {
    this.autoDailyCheckinEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AutoDailyCheckinSettings.save(context, enabled).catch((error: Error) => {
      console.error('save auto daily check-in setting failed: ' + error.message)
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

  private updateThemeMode(mode: string): void {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    this.themeMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ThemeSettings.save(context, normalizedMode).catch((error: Error) => {
      console.error('save theme settings failed: ' + error.message)
    })
  }

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    this.replyDisplayMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyDisplaySettings.save(context, normalizedMode).catch((error: Error) => {
      console.error('save reply display mode failed: ' + error.message)
    })
  }

  private updateReplyCardStyle(style: string): void {
    const normalized = ReplyCardStyleSettings.normalize(style)
    this.replyCardStyle = normalized
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyCardStyleSettings.save(context, normalized).catch((error: Error) => {
      console.error('save reply card style failed: ' + error.message)
    })
  }

  private updateReplyActionAlignmentMode(mode: string): void {
    const normalized = ReplyActionAlignmentSettings.normalizeMode(mode)
    const effective = ReplyActionAlignmentSettings.effectiveMode(
      normalized,
      this.motionHoldingHandSupported,
    )
    this.replyActionAlignmentMode = normalized
    MotionHandStateService.applyAlignmentMode(effective)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyActionAlignmentSettings.save(context, normalized).catch((error: Error) => {
      console.error('save reply action alignment mode failed: ' + error.message)
    })
  }

  private base64DecodeModeLabel(): string {
    if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_OFF) {
      return '关闭'
    }
    if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_INLINE) {
      return '文内显示'
    }
    return '点击查看'
  }

  private updateBase64DecodeMode(mode: string): void {
    const normalized = ReadingSettings.normalizeBase64DecodeMode(mode)
    this.base64DecodeMode = normalized
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveBase64DecodeMode(context, normalized).catch((error: Error) => {
      console.error('save base64 decode settings failed: ' + error.message)
    })
  }

  private updateRestorePosition(value: boolean): void {
    this.readingRestorePosition = value
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveRestorePosition(context, value).catch((error: Error) => {
      console.error('save reading restore position setting failed: ' + error.message)
    })
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
        console.error('load cache stats failed: ' + error.message)
      })
  }
}
