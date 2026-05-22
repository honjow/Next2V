import { common } from '@kit.AbilityKit'
import {
  ApiConstants,
  ApiDomainSettings,
  AutoDailyCheckinSettings,
  CookieJarSettings,
  DiagnosticsSettings,
  HttpClient,
  LanguageSettings,
  MediaSettings,
  MotionHandStateService,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeSettings,
} from 'shared'

export class SettingsSaveCoordinator {
  static applyApiDomainSideEffects(http: HttpClient, useCoDomain: boolean): void {
    http.setBaseUrl(useCoDomain ? ApiConstants.BASE_URL_CO : ApiConstants.BASE_URL_COM)
    CookieJarSettings.refreshConfiguredState()
    CookieJarSettings.restoreCurrentToWebCookieManager().catch((error: Error) => {
      console.error('restore web cookie failed: ' + error.message)
    })
  }

  static applyReplyActionAlignmentMode(mode: string): void {
    MotionHandStateService.applyAlignmentMode(mode)
  }

  static saveApiDomain(context: common.UIAbilityContext, useCoDomain: boolean): void {
    ApiDomainSettings.save(context, useCoDomain).catch((error: Error) => {
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

  static saveLanguageMode(context: common.UIAbilityContext, mode: string): void {
    LanguageSettings.save(context, mode).catch((error: Error) => {
      console.error('save language settings failed: ' + error.message)
    })
  }

  static saveThemeMode(context: common.UIAbilityContext, mode: string): void {
    ThemeSettings.save(context, mode).catch((error: Error) => {
      console.error('save theme settings failed: ' + error.message)
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
