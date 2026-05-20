import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { promptAction } from '@kit.ArkUI'
import { systemShare } from '@kit.ShareKit'
import {
  CacheSettings,
  DiagnosticsSettings,
  ConciseListRow,
  GroupedListSection,
  HttpClient,
  ReadingSettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeSettings,
  ReplyActionAlignmentSettings,
  ReplyDisplaySettings,
  ReplyCardStyleSettings,
  type CacheStats,
} from 'shared'
import {
  SettingsCheckedMenuItem,
  SettingsDivider,
  SettingsDropdownRow,
  SettingsSectionHeader,
  SettingsToggleRow
} from '../components/SettingsPageComponents'
import {
  SettingsPageCoordinator,
  type SettingsOption,
} from '../model/SettingsPageCoordinator'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'
import { StorageSettingsCoordinator } from '../model/StorageSettingsCoordinator'
@Component
export struct SettingsPage {
  @Consume('ns') stack: NavPathStack;
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false;
  @StorageLink(StorageKeys.AUTO_DAILY_CHECKIN_ENABLED) autoDailyCheckinEnabled: boolean = true;
  @StorageLink(StorageKeys.DIAGNOSTICS_ENABLED) diagnosticsEnabled: boolean = true;
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
          this.DiagnosticsSection()
        }
        ListItem() {
          this.ApiDomainAdvancedSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  SectionHeader(title: string) {
    SettingsSectionHeader({ title })
  }

  @Builder
  SettingsDivider() {
    SettingsDivider()
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
  DiagnosticsSection() {
    GroupedListSection() {
      this.TogglePreferenceRow('诊断日志', this.diagnosticsEnabled, (value: boolean) => {
        this.updateDiagnosticsEnabled(value)
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '分享诊断日志',
        subtitle: '通过系统分享已脱敏的本机日志',
        action: () => {
          this.shareDiagnosticsText()
        },
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '复制诊断日志',
        subtitle: '只复制已脱敏的本机日志',
        action: () => {
          this.copyDiagnosticsText()
        },
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '清空诊断日志',
        showChevron: false,
        action: () => {
          this.clearDiagnosticsText()
        },
      })
    }
  }

  @Builder
  ApiDomainAdvancedSection() {
    GroupedListSection() {
      SettingsDropdownRow({
        title: 'API 域名',
        trailingText: SettingsPageCoordinator.apiDomainLabel(this.useCoDomain),
        openAction: () => {
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
    SettingsToggleRow({
      title,
      checked,
      isEnabled,
      changeAction
    })
  }

  @Builder
  DisabledWifiImagePreferenceRow() {
    SettingsToggleRow({
      title: '仅 Wi-Fi 加载图片',
      checked: this.onlyLoadImagesOnWifi,
      isEnabled: false,
      changeAction: (_value: boolean) => {},
    })
  }

  @Builder
  ReadingPreferenceRows() {
    Column() {
      SettingsDropdownRow({
        title: '主题',
        trailingText: ThemeSettings.modeText(this.themeMode),
        openAction: () => {
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
      SettingsDropdownRow({
        title: '回复显示',
        trailingText: ReplyDisplaySettings.modeText(this.replyDisplayMode),
        openAction: () => {
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
      SettingsDropdownRow({
        title: '回复样式',
        trailingText: ReplyCardStyleSettings.styleText(this.replyCardStyle),
        openAction: () => {
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
      SettingsDropdownRow({
        title: '回复按钮对齐方式',
        trailingText: ReplyActionAlignmentSettings.modeText(
          this.replyActionAlignmentMode,
          this.motionHoldingHandSupported,
        ),
        openAction: () => {
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
      SettingsDropdownRow({
        title: 'Base64 解码',
        subtitle: '默认点击查看，避免直接暴露邮箱/微信等明文',
        trailingText: this.base64DecodeModeLabel(),
        openAction: () => {
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
      ForEach(SettingsPageCoordinator.themeModeOptions(), (option: SettingsOption) => {
        this.ThemeModeMenuItem(option)
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  ReplyDisplayModeMenu() {
    Menu() {
      ForEach(SettingsPageCoordinator.replyDisplayModeOptions(), (option: SettingsOption) => {
        this.ReplyDisplayModeMenuItem(option)
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  ReplyCardStyleMenu() {
    Menu() {
      ForEach(SettingsPageCoordinator.replyCardStyleOptions(), (option: SettingsOption) => {
        this.ReplyCardStyleMenuItem(option)
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  ReplyActionAlignmentMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.replyActionAlignmentOptions(this.motionHoldingHandSupported),
        (option: SettingsOption) => {
          this.ReplyActionAlignmentMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  Base64ModeMenu() {
    Menu() {
      ForEach(SettingsPageCoordinator.base64DecodeModeOptions(), (option: SettingsOption) => {
        this.Base64ModeMenuItem(option)
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  Base64ModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.base64DecodeMode === option.value,
      selectAction: () => {
        this.updateBase64DecodeMode(option.value)
      }
    })
  }

  @Builder
  ReplyCardStyleMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.replyCardStyle === option.value,
      selectAction: () => {
        this.updateReplyCardStyle(option.value)
      }
    })
  }

  @Builder
  ReplyActionAlignmentMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: ReplyActionAlignmentSettings.effectiveMode(
        this.replyActionAlignmentMode,
        this.motionHoldingHandSupported,
      ) === option.value,
      selectAction: () => {
        this.updateReplyActionAlignmentMode(option.value)
      }
    })
  }

  @Builder
  ApiDomainMenu() {
    Menu() {
      ForEach(SettingsPageCoordinator.apiDomainOptions(), (option: SettingsOption) => {
        this.ApiDomainMenuItem(option)
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  ApiDomainMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.useCoDomain === (option.value === 'true'),
      selectAction: () => {
        this.updateApiDomain(option.value === 'true')
      }
    })
  }

  @Builder
  ThemeModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.themeMode === option.value,
      selectAction: () => {
        this.updateThemeMode(option.value)
      }
    })
  }

  @Builder
  ReplyDisplayModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.replyDisplayMode === option.value,
      selectAction: () => {
        this.updateReplyDisplayMode(option.value)
      }
    })
  }

  private showThemeMenu(): void {
    this.themeMenuShown = false
    setTimeout(() => {
      this.themeMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showReplyDisplayMenu(): void {
    this.replyDisplayMenuShown = false
    setTimeout(() => {
      this.replyDisplayMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showReplyCardStyleMenu(): void {
    this.replyCardStyleMenuShown = false
    setTimeout(() => {
      this.replyCardStyleMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showReplyActionAlignmentMenu(): void {
    this.replyActionAlignmentMenuShown = false
    setTimeout(() => {
      this.replyActionAlignmentMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showBase64ModeMenu(): void {
    this.base64ModeMenuShown = false
    setTimeout(() => {
      this.base64ModeMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showApiDomainMenu(): void {
    this.apiDomainMenuShown = false
    setTimeout(() => {
      this.apiDomainMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '存储',
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        count: this.cacheStats.topicListCount + this.cacheStats.topicDetailCount,
        action: () => {
          this.stack.pushPathByName('Storage', null)
        },
      })
    }
  }

  private updateApiDomain(useCoDomain: boolean): void {
    this.useCoDomain = useCoDomain
    SettingsSaveCoordinator.applyApiDomainSideEffects(this.http, useCoDomain)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveApiDomain(context, useCoDomain)
  }

  private updateAutoLoadImages(autoLoadImages: boolean): void {
    this.autoLoadImages = autoLoadImages
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveMedia(context, autoLoadImages, this.onlyLoadImagesOnWifi)
  }

  private updateAutoDailyCheckin(enabled: boolean): void {
    this.autoDailyCheckinEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveAutoDailyCheckin(context, enabled)
  }

  private updateDiagnosticsEnabled(enabled: boolean): void {
    this.diagnosticsEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveDiagnostics(context, enabled)
  }

  private copyDiagnosticsText(): void {
    this.copyDiagnosticsTextWithToast('诊断日志已复制', '复制失败')
  }

  private shareDiagnosticsText(): void {
    const text = DiagnosticsSettings.exportText() || '暂无诊断日志'
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      title: 'Next2V 诊断日志',
      description: '已脱敏的本机诊断日志',
      content: text,
    })
    const controller = new systemShare.ShareController(data)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    controller
      .show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      })
      .catch((_error: Error) => {
        this.copyDiagnosticsTextWithToast('分享不可用，已复制，可手动粘贴', '分享失败')
      })
  }

  private copyDiagnosticsTextWithToast(successMessage: string, failureMessage: string): void {
    try {
      const text = DiagnosticsSettings.exportText() || '暂无诊断日志'
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      pasteboard.getSystemPasteboard().setDataSync(data)
      promptAction.openToast({ message: successMessage }).catch((_error: Error) => {})
    } catch (_error) {
      promptAction.openToast({ message: failureMessage }).catch((_toastError: Error) => {})
    }
  }

  private clearDiagnosticsText(): void {
    DiagnosticsSettings.clearLogs()
    promptAction.openToast({ message: '诊断日志已清空' }).catch((_error: Error) => {})
  }

  private updateOnlyLoadImagesOnWifi(onlyLoadImagesOnWifi: boolean): void {
    if (!this.autoLoadImages) {
      return
    }
    this.onlyLoadImagesOnWifi = onlyLoadImagesOnWifi
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveMedia(context, this.autoLoadImages, onlyLoadImagesOnWifi)
  }

  private updateThemeMode(mode: string): void {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    this.themeMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveThemeMode(context, normalizedMode)
  }

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    this.replyDisplayMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveReplyDisplayMode(context, normalizedMode)
  }

  private updateReplyCardStyle(style: string): void {
    const normalized = ReplyCardStyleSettings.normalize(style)
    this.replyCardStyle = normalized
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveReplyCardStyle(context, normalized)
  }

  private updateReplyActionAlignmentMode(mode: string): void {
    const normalized = ReplyActionAlignmentSettings.normalizeMode(mode)
    const effective = ReplyActionAlignmentSettings.effectiveMode(
      normalized,
      this.motionHoldingHandSupported,
    )
    this.replyActionAlignmentMode = normalized
    SettingsSaveCoordinator.applyReplyActionAlignmentMode(effective)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveReplyActionAlignmentMode(context, normalized)
  }

  private base64DecodeModeLabel(): string {
    return SettingsPageCoordinator.base64DecodeModeLabel(this.base64DecodeMode)
  }

  private updateBase64DecodeMode(mode: string): void {
    const normalized = ReadingSettings.normalizeBase64DecodeMode(mode)
    this.base64DecodeMode = normalized
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveBase64DecodeMode(context, normalized)
  }

  private updateRestorePosition(value: boolean): void {
    this.readingRestorePosition = value
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveRestorePosition(context, value)
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
