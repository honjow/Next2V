import { common } from '@kit.AbilityKit'
import {
  ApiDomainSettings,
  AutoDailyCheckinSettings,
  AvatarAppearanceSettings,
  CookieJarSettings,
  DiagnosticsSettings,
  HomeTabSettings,
  HotReplySettings,
  HttpClient,
  LanguageSettings,
  MediaSettings,
  MotionHandStateService,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeColorSettings,
  ThemeSettings,
  TopicDetailReplyActionSettings,
} from 'shared'

export class SettingsSaveCoordinator {
  static applyApiDomainSideEffects(http: HttpClient, baseUrl: string): void {
    http.setBaseUrl(baseUrl)
    CookieJarSettings.refreshConfiguredState()
    CookieJarSettings.restoreCurrentToWebCookieManager().catch((error: Error) => {
      console.error('restore web cookie failed: ' + error.message)
    })
  }

  static applyReplyActionAlignmentMode(mode: string): void {
    MotionHandStateService.applyAlignmentMode(mode)
  }

  static saveApiDomain(context: common.UIAbilityContext, baseUrl: string): void {
    ApiDomainSettings.save(context, baseUrl).catch((error: Error) => {
      console.error('save api domain failed: ' + error.message)
    })
  }

  static saveAutoDailyCheckin(context: common.UIAbilityContext, enabled: boolean): void {
    AutoDailyCheckinSettings.save(context, enabled).catch((error: Error) => {
      console.error('save auto daily check-in setting failed: ' + error.message)
    })
  }

  static saveDiagnostics(context: common.UIAbilityContext, enabled: boolean): void {
    DiagnosticsSettings.save(context, enabled).catch((error: Error) => {
      console.error('save diagnostics setting failed: ' + error.message)
    })
  }

  static saveMedia(
    context: common.UIAbilityContext,
    autoLoadImages: boolean,
    onlyLoadImagesOnWifi: boolean,
  ): void {
    MediaSettings.save(context, autoLoadImages, onlyLoadImagesOnWifi).catch((error: Error) => {
      console.error('save media settings failed: ' + error.message)
    })
  }

  static saveHomeTabAutoHide(context: common.UIAbilityContext, enabled: boolean): void {
    HomeTabSettings.save(context, enabled).catch((error: Error) => {
      console.error('save home tab auto-hide setting failed: ' + error.message)
    })
  }

  static saveTopicDetailReplyButtonAutoHide(context: common.UIAbilityContext, enabled: boolean): void {
    TopicDetailReplyActionSettings.save(context, enabled).catch((error: Error) => {
      console.error('save topic detail reply button auto-hide setting failed: ' + error.message)
    })
  }

  static saveLanguageMode(context: common.UIAbilityContext, mode: string): void {
    LanguageSettings.save(context, mode).catch((error: Error) => {
      console.error('save language settings failed: ' + error.message)
    })
  }

  static saveAvatarAppearance(context: common.UIAbilityContext, appearance: string): void {
    AvatarAppearanceSettings.save(context, appearance).catch((error: Error) => {
      console.error('save avatar appearance failed: ' + error.message)
    })
  }

  static saveThemeMode(context: common.UIAbilityContext, mode: string): void {
    ThemeSettings.save(context, mode).catch((error: Error) => {
      console.error('save theme settings failed: ' + error.message)
    })
  }

  static saveThemeColor(context: common.UIAbilityContext, color: string): void {
    ThemeColorSettings.save(context, color).catch((error: Error) => {
      console.error('save theme color setting failed: ' + error.message)
    })
  }

  static saveReplyDisplayMode(context: common.UIAbilityContext, mode: string): void {
    ReplyDisplaySettings.save(context, mode).catch((error: Error) => {
      console.error('save reply display mode failed: ' + error.message)
    })
  }

  static saveReplyCardStyle(context: common.UIAbilityContext, style: string): void {
    ReplyCardStyleSettings.save(context, style).catch((error: Error) => {
      console.error('save reply card style failed: ' + error.message)
    })
  }

  static saveReplyActionAlignmentMode(context: common.UIAbilityContext, mode: string): void {
    ReplyActionAlignmentSettings.save(context, mode).catch((error: Error) => {
      console.error('save reply action alignment mode failed: ' + error.message)
    })
  }

  static saveHotReplies(
    context: common.UIAbilityContext,
    enabled: boolean,
    maxCount: number,
    minThanks: number,
  ): void {
    HotReplySettings.save(context, enabled, maxCount, minThanks).catch((error: Error) => {
      console.error('save hot reply settings failed: ' + error.message)
    })
  }

  static saveBase64DecodeMode(context: common.UIAbilityContext, mode: string): void {
    ReadingSettings.saveBase64DecodeMode(context, mode).catch((error: Error) => {
      console.error('save base64 decode settings failed: ' + error.message)
    })
  }

  static saveRestorePosition(context: common.UIAbilityContext, value: boolean): void {
    ReadingSettings.saveRestorePosition(context, value).catch((error: Error) => {
      console.error('save reading restore position setting failed: ' + error.message)
    })
  }
}
