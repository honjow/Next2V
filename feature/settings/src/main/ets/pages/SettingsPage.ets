import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiDomainState,
  AppStrings,
  AvatarAppearanceSettings,
  AvatarAppearanceState,
  CacheSettings,
  CloudSyncState,
  connectApiDomain,
  connectAutoDailyCheckin,
  connectCloudSync,
  connectAvatarAppearance,
  connectHomeTabAutoHide,
  connectHotReplySettings,
  connectImageUpload,
  connectLanguageState,
  connectMediaSettings,
  connectMotionReplyAlignment,
  connectNavStack,
  connectNetworkProxy,
  connectReadingSettings,
  connectReplyCardStyle,
  connectReplyDisplay,
  connectThemeColor,
  connectThemeDisplay,
  connectTopicDetailReplyButton,
  ConciseListRow,
  GroupedListSection,
  HomeTabSettings,
  HotReplySettingsState,
  HttpClient,
  ImageUploadState,
  NetworkProxySettings,
  NetworkProxyState,
  LanguageSettings,
  ReadingSettings,
  ReadingSettingsState,
  SecondaryListScaffold,
  ThemeColorSettings,
  ThemeColorState,
  ThemeSettings,
  ReplyActionAlignmentSettings,
  ReplyDisplaySettings,
  ReplyCardStyleSettings,
  ReplyCardStyleState,
  TopicDetailReplyButtonState,
  type CacheStats,
  type ThemeColorOption,
} from 'shared'
import {
  SettingsCheckedMenuItem,
  SettingsDivider,
  SettingsDropdownRow,
  SettingsSectionHeader,
  SettingsThemeColorDropdownRow,
  SettingsToggleRow,
} from '../components/SettingsPageComponents'
import { SettingsPageCoordinator, type SettingsOption } from '../model/SettingsPageCoordinator'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'
import { StorageSettingsCoordinator } from '../model/StorageSettingsCoordinator'
@ComponentV2
export struct SettingsPage {
  // `ns` is the app-wide NavPathStack from NavStackHolder (was @Consume('ns')).
  private stack: NavPathStack = connectNavStack().stack;
  // Settings that a pushed sub-page (or another surface) can change while this page instance is alive
  // are read from their V2 mirrors so the page stays reactive across the V1/V2 boundary; each mirror
  // is dual-written synchronously at its settings apply()/save() chokepoint:
  //   - domain (DomainSettings), proxy (NetworkProxySettings) change via sub-pages;
  //   - avatar / replyCardStyle / reading-base64 / topic-reply-button are toggled here, but their
  //     existing mirrors already give a free reactive + synchronous source so we read them too.
  private domain: ApiDomainState = connectApiDomain();
  private avatar: AvatarAppearanceState = connectAvatarAppearance();
  private replyCardStyleState: ReplyCardStyleState = connectReplyCardStyle();
  private hotReplies: HotReplySettingsState = connectHotReplySettings();
  private topicReplyButton: TopicDetailReplyButtonState = connectTopicDetailReplyButton();
  private reading: ReadingSettingsState = connectReadingSettings();
  private proxy: NetworkProxyState = connectNetworkProxy();
  private image: ImageUploadState = connectImageUpload();
  private themeColor: ThemeColorState = connectThemeColor();
  // Cloud-sync master-enabled state, read only to show the on/off status on the "云同步" entry row. The
  // full cloud-sync UI lives in the pushed CloudSyncSettingsPage; this is just a reactive @Trace read.
  private cloudSync: CloudSyncState = connectCloudSync();
  // Settings toggled only on this page (single writer while visible) are @Local: hydrated from
  // AppStorage in aboutToAppear and updated optimistically by the toggle handlers below.
  @Local private autoDailyCheckinEnabled: boolean = true;
  @Local private autoLoadImages: boolean = true;
  @Local private onlyLoadImagesOnWifi: boolean = false;
  @Local private themeMode: string = ThemeSettings.MODE_AUTO;
  @Local private languageMode: string = LanguageSettings.MODE_SYSTEM;
  @Local private replyDisplayMode: string = ReplyDisplaySettings.MODE_THREAD;
  @Local private replyActionAlignmentMode: string = ReplyActionAlignmentSettings.MODE_UNSET;
  @Local private homeTabAutoHide: boolean = HomeTabSettings.DEFAULT_AUTO_HIDE;
  @Local private motionHoldingHandSupported: boolean = false;
  @Local private readingRestorePosition: boolean = false;
  @Local private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 };
  @Local private themeColorMenuShown: boolean = false;
  @Local private themeMenuShown: boolean = false;
  @Local private languageMenuShown: boolean = false;
  @Local private avatarAppearanceMenuShown: boolean = false;
  @Local private replyDisplayMenuShown: boolean = false;
  @Local private replyCardStyleMenuShown: boolean = false;
  @Local private replyActionAlignmentMenuShown: boolean = false;
  @Local private base64ModeMenuShown: boolean = false;
  private http: HttpClient = HttpClient.getInstance();

  aboutToAppear(): void {
    this.hydratePreferences()
    this.loadCacheStats()
  }

  // Hydrate the @Local self-toggled preferences from their durable V2 holders (seeded by each setting's
  // apply()/save() chokepoint and by SettingsBootstrap at startup), replacing the former direct
  // AppStorage.get reads. The mirror-backed settings (domain/avatar/replyCardStyle/reading-base64/
  // proxy/topicReplyButton) need no hydration — their connect* singletons already hold the live value.
  // Holder defaults match the prior `?? <default>` fallbacks (auto checkin on, auto-load images on,
  // wifi-only off, theme 'auto', language 'default', reply display 'thread', alignment unset, home-tab
  // auto-hide default, holding-hand unsupported, restore-position on).
  private hydratePreferences(): void {
    this.autoDailyCheckinEnabled = connectAutoDailyCheckin().enabled
    const media = connectMediaSettings()
    this.autoLoadImages = media.autoLoadImages
    this.onlyLoadImagesOnWifi = media.onlyLoadImagesOnWifi
    this.themeMode = connectThemeDisplay().mode
    this.languageMode = connectLanguageState().mode
    this.replyDisplayMode = connectReplyDisplay().mode
    const alignment = connectMotionReplyAlignment()
    this.replyActionAlignmentMode = alignment.alignmentMode
    this.homeTabAutoHide = connectHomeTabAutoHide().autoHide
    this.motionHoldingHandSupported = alignment.holdingHandSupported
    this.readingRestorePosition = this.reading.restorePosition
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.SectionHeader($r('app.string.account_section'))
        }
        ListItem() {
          this.AccountSection()
        }
        ListItem() {
          this.SectionHeader($r('app.string.settings_appearance'))
        }
        ListItem() {
          this.AppearanceSection()
        }
        ListItem() {
          this.SectionHeader($r('app.string.settings_reading'))
        }
        ListItem() {
          this.ReadingSection()
        }
        ListItem() {
          this.SectionHeader($r('app.string.settings_navigation_actions'))
        }
        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: $r('app.string.nav_home_nodes'),
              action: () => {
                this.stack.pushPathByName('HomeNodeSettings', null)
              },
            })
            this.SettingsDivider()
            this.TogglePreferenceRow(
              $r('app.string.home_tab_auto_hide'),
              this.homeTabAutoHide,
              (value: boolean) => {
                this.updateHomeTabAutoHide(value)
              },
            )
            this.SettingsDivider()
            this.TogglePreferenceRow(
              $r('app.string.topic_detail_reply_button_auto_hide'),
              this.topicReplyButton.autoHide,
              (value: boolean) => {
                this.updateTopicDetailReplyButtonAutoHide(value)
              },
            )
          }
        }
        ListItem() {
          this.SectionHeader($r('app.string.settings_content_media'))
        }
        ListItem() {
          this.MediaSection()
        }
        ListItem() {
          this.SectionHeader($r('app.string.nav_storage'))
        }
        ListItem() {
          this.CacheSection()
        }
        ListItem() {
          this.SectionHeader($r('app.string.settings_advanced'))
        }
        ListItem() {
          this.DiagnosticsSection()
        }
        ListItem() {
          this.ApiDomainAdvancedSection()
        }
        ListItem() {
          this.NetworkAdvancedSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  SectionHeader(title: ResourceStr) {
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
        title: $r('app.string.account_management'),
        action: () => {
          this.stack.pushPathByName('Account', null)
        },
      })
      this.SettingsDivider()
      this.TogglePreferenceRow(
        $r('app.string.auto_checkin'),
        this.autoDailyCheckinEnabled,
        (value: boolean) => {
          this.updateAutoDailyCheckin(value)
        },
      )
      this.SettingsDivider()
      ConciseListRow({
        title: $r('app.string.cloud_sync'),
        trailingText: this.cloudSync.enabled
          ? $r('app.string.common_open')
          : $r('app.string.common_closed'),
        action: () => {
          this.stack.pushPathByName('CloudSyncSettings', null)
        },
      })
    }
  }

  @Builder
  AppearanceSection() {
    GroupedListSection() {
      this.AppearancePreferenceRows()
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
      this.TogglePreferenceRow(
        $r('app.string.image_auto_load'),
        this.autoLoadImages,
        (value: boolean) => {
          this.updateAutoLoadImages(value)
        },
      )

      this.SettingsDivider()

      if (this.autoLoadImages) {
        this.TogglePreferenceRow(
          $r('app.string.wifi_only_images'),
          this.onlyLoadImagesOnWifi,
          (value: boolean) => {
            this.updateOnlyLoadImagesOnWifi(value)
          },
        )
      } else {
        this.DisabledWifiImagePreferenceRow()
      }

      this.SettingsDivider()
      ConciseListRow({
        title: $r('app.string.image_upload_settings_title'),
        trailingText: this.isImageUploadConfigured()
          ? $r('app.string.image_upload_summary_configured')
          : $r('app.string.proxy_not_configured'),
        action: () => {
          this.stack.pushPathByName('ImageUploadSettings', null)
        },
      })
    }
  }

  // Whether the active image host (mirror's provider) has its credential set. Reads the @Trace fields
  // directly so the row's "configured" state refreshes after a save.
  private isImageUploadConfigured(): boolean {
    if (this.image.provider === 'smms') {
      return this.image.smmsToken.length > 0
    }
    if (this.image.provider === 'imgur') {
      return this.image.imgurClientId.length > 0
    }
    return this.image.imgbbApiKey.length > 0
  }

  @Builder
  DiagnosticsSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.nav_diagnostics'),
        action: () => {
          this.stack.pushPathByName('DiagnosticsLog', null)
        },
      })
    }
  }

  @Builder
  ApiDomainAdvancedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.api_domain'),
        trailingText: SettingsPageCoordinator.apiDomainLabel(this.domain.selectedBaseUrl),
        action: () => {
          this.stack.pushPathByName('DomainSettings', null)
        },
      })
    }
  }

  @Builder
  NetworkAdvancedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.nav_network_proxy'),
        trailingText: NetworkProxySettings.summary({
          mode: NetworkProxySettings.normalizeMode(this.proxy.mode),
          host: this.proxy.host,
          port: this.proxy.port,
          proxyScheme: NetworkProxySettings.normalizeProxyScheme(this.proxy.proxyScheme),
          username: '',
          password: '',
          exclusionList: [],
        }),
        action: () => {
          this.stack.pushPathByName('NetworkProxySettings', null)
        },
      })
    }
  }

  @Builder
  TogglePreferenceRow(
    title: ResourceStr,
    checked: boolean,
    changeAction: (value: boolean) => void,
    isEnabled: boolean = true,
  ) {
    SettingsToggleRow({
      title,
      checked,
      isEnabled,
      changeAction,
    })
  }

  @Builder
  DisabledWifiImagePreferenceRow() {
    SettingsToggleRow({
      title: $r('app.string.wifi_only_images'),
      checked: this.onlyLoadImagesOnWifi,
      isEnabled: false,
      changeAction: (_value: boolean) => {},
    })
  }

  @Builder
  AppearancePreferenceRows() {
    Column() {
      SettingsThemeColorDropdownRow({
        title: $r('app.string.theme_color'),
        trailingText: SettingsPageCoordinator.themeColorLabel(this.themeColor.color),
        color: SettingsPageCoordinator.themeColorValue(this.themeColor.color),
        openAction: () => {
          this.showThemeColorMenu()
        },
      })
        .bindMenu(this.themeColorMenuShown, this.ThemeColorMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.themeColorMenuShown = false
          },
        })

      this.SettingsDivider()
      SettingsDropdownRow({
        title: $r('app.string.theme'),
        trailingText: SettingsPageCoordinator.themeModeLabel(this.themeMode),
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
        title: $r('app.string.avatar_appearance'),
        trailingText: SettingsPageCoordinator.avatarAppearanceLabel(this.avatar.appearance),
        openAction: () => {
          this.showAvatarAppearanceMenu()
        },
      })
        .bindMenu(this.avatarAppearanceMenuShown, this.AvatarAppearanceMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.avatarAppearanceMenuShown = false
          },
        })

      this.SettingsDivider()
      SettingsDropdownRow({
        title: $r('app.string.language'),
        trailingText: SettingsPageCoordinator.languageModeLabel(this.languageMode),
        openAction: () => {
          this.showLanguageMenu()
        },
      })
        .bindMenu(this.languageMenuShown, this.LanguageModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.languageMenuShown = false
          },
        })
    }.width('100%')
  }

  @Builder
  ReadingPreferenceRows() {
    Column() {
      SettingsDropdownRow({
        title: $r('app.string.reply_display'),
        trailingText: SettingsPageCoordinator.replyDisplayModeLabel(this.replyDisplayMode),
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
        title: $r('app.string.reply_style'),
        trailingText: SettingsPageCoordinator.replyCardStyleLabel(
          this.replyCardStyleState.replyCardStyle,
        ),
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
        title: $r('app.string.reply_action_alignment'),
        trailingText: SettingsPageCoordinator.replyActionAlignmentLabel(
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
      ConciseListRow({
        title: $r('app.string.hot_replies'),
        trailingText: this.hotReplies.enabled
          ? $r('app.string.common_open')
          : $r('app.string.common_closed'),
        action: () => {
          this.stack.pushPathByName('HotReplySettings', null)
        },
      })

      this.SettingsDivider()

      this.TogglePreferenceRow(
        $r('app.string.remember_read_position'),
        this.readingRestorePosition,
        (value: boolean) => {
          this.updateRestorePosition(value)
        },
      )

      this.SettingsDivider()
      SettingsDropdownRow({
        title: $r('app.string.base64_decode'),
        subtitle: $r('app.string.base64_subtitle'),
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
        title: $r('app.string.nav_reading'),
        action: () => {
          this.stack.pushPathByName('ReadingSettings', null)
        },
      })
    }.width('100%')
  }

  @Builder
  LanguageModeMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.languageModeOptions(),
        (option: SettingsOption) => {
          this.LanguageModeMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  ThemeModeMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.themeModeOptions(),
        (option: SettingsOption) => {
          this.ThemeModeMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  ThemeColorMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.themeColorOptions(),
        (option: ThemeColorOption) => {
          this.ThemeColorMenuItem(option)
        },
        (option: ThemeColorOption) => option.value,
      )
    }
  }

  @Builder
  AvatarAppearanceMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.avatarAppearanceOptions(),
        (option: SettingsOption) => {
          this.AvatarAppearanceMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  ReplyDisplayModeMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.replyDisplayModeOptions(),
        (option: SettingsOption) => {
          this.ReplyDisplayModeMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  ReplyCardStyleMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.replyCardStyleOptions(),
        (option: SettingsOption) => {
          this.ReplyCardStyleMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
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
      ForEach(
        SettingsPageCoordinator.base64DecodeModeOptions(),
        (option: SettingsOption) => {
          this.Base64ModeMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  AvatarAppearanceMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: AvatarAppearanceSettings.normalize(this.avatar.appearance) === option.value,
      selectAction: () => {
        this.updateAvatarAppearance(option.value)
      },
    })
  }

  @Builder
  Base64ModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.reading.base64DecodeMode === option.value,
      selectAction: () => {
        this.updateBase64DecodeMode(option.value)
      },
    })
  }

  @Builder
  ReplyCardStyleMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.replyCardStyleState.replyCardStyle === option.value,
      selectAction: () => {
        this.updateReplyCardStyle(option.value)
      },
    })
  }

  @Builder
  ReplyActionAlignmentMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected:
        ReplyActionAlignmentSettings.effectiveMode(
          this.replyActionAlignmentMode,
          this.motionHoldingHandSupported,
        ) === option.value,
      selectAction: () => {
        this.updateReplyActionAlignmentMode(option.value)
      },
    })
  }

  @Builder
  LanguageModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: LanguageSettings.normalizeMode(this.languageMode) === option.value,
      selectAction: () => {
        this.updateLanguageMode(option.value)
      },
    })
  }

  @Builder
  ThemeModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.themeMode === option.value,
      selectAction: () => {
        this.updateThemeMode(option.value)
      },
    })
  }

  @Builder
  ThemeColorMenuItem(option: ThemeColorOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: ThemeColorSettings.normalizeColor(this.themeColor.color) === option.value,
      showColorDot: true,
      color: option.color,
      selectAction: () => {
        this.updateThemeColor(option.value)
      },
    })
  }

  @Builder
  ReplyDisplayModeMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected: this.replyDisplayMode === option.value,
      selectAction: () => {
        this.updateReplyDisplayMode(option.value)
      },
    })
  }

  private showLanguageMenu(): void {
    this.languageMenuShown = false
    setTimeout(() => {
      this.languageMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showThemeMenu(): void {
    this.themeMenuShown = false
    setTimeout(() => {
      this.themeMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showThemeColorMenu(): void {
    this.themeColorMenuShown = false
    setTimeout(() => {
      this.themeColorMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showAvatarAppearanceMenu(): void {
    this.avatarAppearanceMenuShown = false
    setTimeout(() => {
      this.avatarAppearanceMenuShown = true
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

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.nav_storage'),
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        count: this.cacheStats.topicListCount + this.cacheStats.topicDetailCount,
        action: () => {
          this.stack.pushPathByName('Storage', null)
        },
      })
    }
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

  private updateHomeTabAutoHide(enabled: boolean): void {
    this.homeTabAutoHide = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveHomeTabAutoHide(context, enabled)
  }

  private updateTopicDetailReplyButtonAutoHide(enabled: boolean): void {
    // save() -> TopicDetailReplyActionSettings.apply() synchronously dual-writes the mirror the
    // toggle reads (this.topicReplyButton.autoHide), so no optimistic local set is needed.
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveTopicDetailReplyButtonAutoHide(context, enabled)
  }

  private updateOnlyLoadImagesOnWifi(onlyLoadImagesOnWifi: boolean): void {
    if (!this.autoLoadImages) {
      return
    }
    this.onlyLoadImagesOnWifi = onlyLoadImagesOnWifi
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveMedia(context, this.autoLoadImages, onlyLoadImagesOnWifi)
  }

  private updateLanguageMode(mode: string): void {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.normalizeMode(this.languageMode)) {
      this.languageMenuShown = false
      return
    }
    this.languageMenuShown = false
    this.languageMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    LanguageSettings.applyLanguage(context, normalizedMode).catch((error: Error) => {
      console.error('switch app language failed: ' + error.message)
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.common_save_failed'), 'Save failed'),
        })
        .catch((_toastError: Error) => {})
    })
  }

  private updateAvatarAppearance(appearance: string): void {
    const normalized = AvatarAppearanceSettings.normalize(appearance)
    // saveAvatarAppearance -> apply() synchronously dual-writes this.avatar.appearance (the mirror
    // the menu reads), so no optimistic local set is needed.
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveAvatarAppearance(context, normalized)
  }

  private updateThemeMode(mode: string): void {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    this.themeMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveThemeMode(context, normalizedMode)
  }

  private updateThemeColor(color: string): void {
    const normalized = ThemeColorSettings.normalizeColor(color)
    this.themeColorMenuShown = false
    if (normalized === ThemeColorSettings.normalizeColor(this.themeColor.color)) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveThemeColor(context, normalized)
  }

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    this.replyDisplayMode = normalizedMode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveReplyDisplayMode(context, normalizedMode)
  }

  private updateReplyCardStyle(style: string): void {
    const normalized = ReplyCardStyleSettings.normalize(style)
    // saveReplyCardStyle -> apply() synchronously dual-writes this.replyCardStyleState.replyCardStyle
    // (the mirror the menu reads), so no optimistic local set is needed.
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

  private base64DecodeModeLabel(): ResourceStr {
    return SettingsPageCoordinator.base64DecodeModeLabel(this.reading.base64DecodeMode)
  }

  private updateBase64DecodeMode(mode: string): void {
    const normalized = ReadingSettings.normalizeBase64DecodeMode(mode)
    // saveBase64DecodeMode synchronously dual-writes this.reading.base64DecodeMode (the mirror the
    // menu reads), so no optimistic local set is needed.
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
