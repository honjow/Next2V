import {
  AppStrings,
  AvatarAppearanceSettings,
  LanguageSettings,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeSettings,
  ApiDomainSettings,
} from 'shared'

export interface SettingsOption {
  label: ResourceStr
  value: string
}

export class SettingsPageCoordinator {
  static readonly MENU_OPEN_DELAY_MS: number = 20

  static languageModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_LANGUAGE_FOLLOW_SYSTEM, value: LanguageSettings.MODE_SYSTEM },
      { label: AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE, value: LanguageSettings.MODE_ZH_CN },
      { label: AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK, value: LanguageSettings.MODE_ZH_HK },
      { label: AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW, value: LanguageSettings.MODE_ZH_TW },
      { label: AppStrings.R_LANGUAGE_ENGLISH, value: LanguageSettings.MODE_EN },
      { label: AppStrings.R_LANGUAGE_JAPANESE, value: LanguageSettings.MODE_JA },
      { label: AppStrings.R_LANGUAGE_KOREAN, value: LanguageSettings.MODE_KO },
    ]
  }

  static themeModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_COMMON_AUTO, value: ThemeSettings.MODE_AUTO },
      { label: AppStrings.R_COMMON_LIGHT, value: ThemeSettings.MODE_LIGHT },
      { label: AppStrings.R_COMMON_DARK, value: ThemeSettings.MODE_DARK },
    ]
  }

  static avatarAppearanceOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_AVATAR_APPEARANCE_SOFT, value: AvatarAppearanceSettings.APPEARANCE_SOFT },
      { label: AppStrings.R_AVATAR_APPEARANCE_CIRCLE, value: AvatarAppearanceSettings.APPEARANCE_CIRCLE },
    ]
  }

  static replyDisplayModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_THREADED, value: ReplyDisplaySettings.MODE_THREAD },
      { label: AppStrings.R_THREADED_AT, value: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: AppStrings.R_THREADED_REDUNDANT, value: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: AppStrings.R_OP_ONLY, value: ReplyDisplaySettings.MODE_OP },
      { label: AppStrings.R_ORIGINAL, value: ReplyDisplaySettings.MODE_ORIGIN },
    ]
  }

  static replyCardStyleOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_DENSITY_STANDARD, value: ReplyCardStyleSettings.STYLE_STANDARD },
      { label: AppStrings.R_DENSITY_COMPACT, value: ReplyCardStyleSettings.STYLE_COMPACT },
    ]
  }

  static replyActionAlignmentOptions(motionHoldingHandSupported: boolean): SettingsOption[] {
    const options: SettingsOption[] = []
    if (motionHoldingHandSupported) {
      options.push({
        label: AppStrings.R_SMART_GRIP,
        value: ReplyActionAlignmentSettings.MODE_SMART_GRIP,
      })
    }
    options.push(
      {
        label: AppStrings.R_FOLLOW_OPERATION,
        value: ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION,
      },
      { label: AppStrings.R_FIXED_LEFT, value: ReplyActionAlignmentSettings.MODE_FIXED_LEFT },
      { label: AppStrings.R_FIXED_RIGHT, value: ReplyActionAlignmentSettings.MODE_FIXED_RIGHT },
    )
    return options
  }

  static base64DecodeModeOptions(): SettingsOption[] {
    return [
      { label: AppStrings.R_COMMON_CLOSED, value: ReadingSettings.BASE64_MODE_OFF },
      { label: AppStrings.R_TAP_TO_VIEW, value: ReadingSettings.BASE64_MODE_BADGE },
      { label: AppStrings.R_INLINE_DISPLAY, value: ReadingSettings.BASE64_MODE_INLINE },
    ]
  }


  static languageModeLabel(mode: string): ResourceStr {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.MODE_ZH_CN) {
      return AppStrings.R_LANGUAGE_SIMPLIFIED_CHINESE
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_HK) {
      return AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_HK
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_TW) {
      return AppStrings.R_LANGUAGE_TRADITIONAL_CHINESE_TW
    }
    if (normalizedMode === LanguageSettings.MODE_EN) {
      return AppStrings.R_LANGUAGE_ENGLISH
    }
    if (normalizedMode === LanguageSettings.MODE_JA) {
      return AppStrings.R_LANGUAGE_JAPANESE
    }
    if (normalizedMode === LanguageSettings.MODE_KO) {
      return AppStrings.R_LANGUAGE_KOREAN
    }
    return AppStrings.R_LANGUAGE_FOLLOW_SYSTEM
  }

  static themeModeLabel(mode: string): ResourceStr {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    if (normalizedMode === ThemeSettings.MODE_LIGHT) {
      return AppStrings.R_COMMON_LIGHT
    }
    if (normalizedMode === ThemeSettings.MODE_DARK) {
      return AppStrings.R_COMMON_DARK
    }
    return AppStrings.R_COMMON_AUTO
  }

  static avatarAppearanceLabel(appearance: string): ResourceStr {
    if (AvatarAppearanceSettings.normalize(appearance) === AvatarAppearanceSettings.APPEARANCE_SOFT) {
      return AppStrings.R_AVATAR_APPEARANCE_SOFT
    }
    return AppStrings.R_AVATAR_APPEARANCE_CIRCLE
  }

  static replyDisplayModeLabel(mode: string): ResourceStr {
    const value = ReplyDisplaySettings.normalizeMode(mode)
    if (value === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION) {
      return AppStrings.R_THREADED_AT
    }
    if (value === ReplyDisplaySettings.MODE_THREAD_REDUNDANT) {
      return AppStrings.R_THREADED_REDUNDANT
    }
    if (value === ReplyDisplaySettings.MODE_OP) {
      return AppStrings.R_OP_ONLY
    }
    if (value === ReplyDisplaySettings.MODE_ORIGIN) {
      return AppStrings.R_ORIGINAL
    }
    return AppStrings.R_THREADED
  }

  static replyCardStyleLabel(style: string): ResourceStr {
    if (ReplyCardStyleSettings.normalize(style) === ReplyCardStyleSettings.STYLE_COMPACT) {
      return AppStrings.R_DENSITY_COMPACT
    }
    return AppStrings.R_DENSITY_STANDARD
  }

  static replyActionAlignmentLabel(mode: string, smartGripSupported: boolean): ResourceStr {
    const effective = ReplyActionAlignmentSettings.effectiveMode(mode, smartGripSupported)
    if (effective === ReplyActionAlignmentSettings.MODE_SMART_GRIP) {
      return AppStrings.R_SMART_GRIP
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_LEFT) {
      return AppStrings.R_FIXED_LEFT
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_RIGHT) {
      return AppStrings.R_FIXED_RIGHT
    }
    return AppStrings.R_FOLLOW_OPERATION
  }


  static base64DecodeModeLabel(mode: string): ResourceStr {
    if (mode === ReadingSettings.BASE64_MODE_OFF) {
      return AppStrings.R_COMMON_CLOSED
    }
    if (mode === ReadingSettings.BASE64_MODE_INLINE) {
      return AppStrings.R_INLINE_DISPLAY
    }
    return AppStrings.R_TAP_TO_VIEW
  }

  static apiDomainLabel(baseUrl: string): string {
    return ApiDomainSettings.normalizeBaseUrl(baseUrl).replace(/^https:\/\//, '')
  }

}
