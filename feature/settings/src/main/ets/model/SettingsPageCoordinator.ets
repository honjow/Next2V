import {
  AppStrings,
  LanguageSettings,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeSettings,
} from 'shared'

export interface SettingsOption {
  label: string
  value: string
}

export class SettingsPageCoordinator {
  static readonly MENU_OPEN_DELAY_MS: number = 20

  static languageModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.t(AppStrings.R_LANGUAGE_FOLLOW_SYSTEM, 'Follow system'), value: LanguageSettings.MODE_SYSTEM },
      { label: AppStrings.t(AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE, 'Simplified Chinese'), value: LanguageSettings.MODE_ZH_CN },
      { label: AppStrings.t(AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK, 'Traditional Chinese (Hong Kong)'), value: LanguageSettings.MODE_ZH_HK },
      { label: AppStrings.t(AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW, 'Traditional Chinese (Taiwan)'), value: LanguageSettings.MODE_ZH_TW },
      { label: AppStrings.t(AppStrings.R_LANGUAGE_ENGLISH, 'English'), value: LanguageSettings.MODE_EN },
    ]
  }

  static themeModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.t(AppStrings.R_COMMON_AUTO, 'Automatic'), value: ThemeSettings.MODE_AUTO },
      { label: AppStrings.t(AppStrings.R_COMMON_LIGHT, 'Light'), value: ThemeSettings.MODE_LIGHT },
      { label: AppStrings.t(AppStrings.R_COMMON_DARK, 'Dark'), value: ThemeSettings.MODE_DARK },
    ]
  }

  static replyDisplayModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.t(AppStrings.R_THREADED, 'Threaded'), value: ReplyDisplaySettings.MODE_THREAD },
      { label: AppStrings.t(AppStrings.R_THREADED_AT, 'Threaded (@)'), value: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: AppStrings.t(AppStrings.R_THREADED_REDUNDANT, 'Redundant threaded'), value: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: AppStrings.t(AppStrings.R_OP_ONLY, 'Original poster only'), value: ReplyDisplaySettings.MODE_OP },
      { label: AppStrings.t(AppStrings.R_ORIGINAL, 'Original'), value: ReplyDisplaySettings.MODE_ORIGIN },
    ]
  }

  static replyCardStyleOptions(): SettingsOption[] {
    return [
      { label: AppStrings.t(AppStrings.R_DENSITY_STANDARD, 'Standard'), value: ReplyCardStyleSettings.STYLE_STANDARD },
      { label: AppStrings.t(AppStrings.R_DENSITY_COMPACT, 'Compact'), value: ReplyCardStyleSettings.STYLE_COMPACT },
    ]
  }

  static replyActionAlignmentOptions(motionHoldingHandSupported: boolean): SettingsOption[] {
    const options: SettingsOption[] = []
    if (motionHoldingHandSupported) {
      options.push({
        label: AppStrings.t(AppStrings.R_SMART_GRIP, 'Smart grip'),
        value: ReplyActionAlignmentSettings.MODE_SMART_GRIP,
      })
    }
    options.push(
      {
        label: AppStrings.t(AppStrings.R_FOLLOW_OPERATION, 'Follow operation'),
        value: ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION,
      },
      { label: AppStrings.t(AppStrings.R_FIXED_LEFT, 'Fixed left'), value: ReplyActionAlignmentSettings.MODE_FIXED_LEFT },
      { label: AppStrings.t(AppStrings.R_FIXED_RIGHT, 'Fixed right'), value: ReplyActionAlignmentSettings.MODE_FIXED_RIGHT },
    )
    return options
  }

  static base64DecodeModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.t(AppStrings.R_COMMON_CLOSED, 'Off'), value: ReadingSettings.BASE64_MODE_OFF },
      { label: AppStrings.t(AppStrings.R_TAP_TO_VIEW, 'Tap to view'), value: ReadingSettings.BASE64_MODE_BADGE },
      { label: AppStrings.t(AppStrings.R_INLINE_DISPLAY, 'Inline display'), value: ReadingSettings.BASE64_MODE_INLINE },
    ]
  }

  static apiDomainOptions(): SettingsOption[] {
    return [
      { label: 'v2ex.com', value: 'false' },
      { label: 'v2ex.co', value: 'true' },
    ]
  }

  static base64DecodeModeLabel(mode: string): string {
    if (mode === ReadingSettings.BASE64_MODE_OFF) {
      return AppStrings.t(AppStrings.R_COMMON_CLOSED, 'Off')
    }
    if (mode === ReadingSettings.BASE64_MODE_INLINE) {
      return AppStrings.t(AppStrings.R_INLINE_DISPLAY, 'Inline display')
    }
    return AppStrings.t(AppStrings.R_TAP_TO_VIEW, 'Tap to view')
  }

  static apiDomainLabel(useCoDomain: boolean): string {
    return useCoDomain ? 'v2ex.co' : 'v2ex.com'
  }

}
