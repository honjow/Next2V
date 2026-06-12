import {
  AppStrings,
  AvatarAppearanceSettings,
  HotReplySettings,
  ImmersiveMaterialSettings,
  LanguageSettings,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeColorSettings,
  ThemeSettings,
  ApiDomainSettings,
  type ImmersiveMaterialOption,
  type ThemeColorOption,
} from 'shared'

export interface SettingsOption {
  label: ResourceStr
  value: string
}

export class SettingsPageCoordinator {
  static readonly MENU_OPEN_DELAY_MS: number = 20

  static languageModeOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.language_follow_system'), value: LanguageSettings.MODE_SYSTEM },
      { label: $r('app.string.language_simplified_chinese'), value: LanguageSettings.MODE_ZH_CN },
      { label: $r('app.string.language_traditional_chinese_hk'), value: LanguageSettings.MODE_ZH_HK },
      { label: $r('app.string.language_traditional_chinese_tw'), value: LanguageSettings.MODE_ZH_TW },
      { label: $r('app.string.language_english'), value: LanguageSettings.MODE_EN },
      { label: $r('app.string.language_japanese'), value: LanguageSettings.MODE_JA },
      { label: $r('app.string.language_korean'), value: LanguageSettings.MODE_KO },
    ]
  }

  static themeModeOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.common_auto'), value: ThemeSettings.MODE_AUTO },
      { label: $r('app.string.common_light'), value: ThemeSettings.MODE_LIGHT },
      { label: $r('app.string.common_dark'), value: ThemeSettings.MODE_DARK },
    ]
  }

  static themeColorOptions(): ThemeColorOption[] {
    return ThemeColorSettings.options()
  }

  static immersiveMaterialOptions(): ImmersiveMaterialOption[] {
    return ImmersiveMaterialSettings.options()
  }

  static avatarAppearanceOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.avatar_appearance_soft'), value: AvatarAppearanceSettings.APPEARANCE_SOFT },
      { label: $r('app.string.avatar_appearance_circle'), value: AvatarAppearanceSettings.APPEARANCE_CIRCLE },
    ]
  }

  static replyDisplayModeOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.threaded'), value: ReplyDisplaySettings.MODE_THREAD },
      { label: $r('app.string.threaded_at'), value: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: $r('app.string.threaded_redundant'), value: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: $r('app.string.op_only'), value: ReplyDisplaySettings.MODE_OP },
      { label: $r('app.string.original'), value: ReplyDisplaySettings.MODE_ORIGIN },
    ]
  }

  static replyCardStyleOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.density_standard'), value: ReplyCardStyleSettings.STYLE_STANDARD },
      { label: $r('app.string.density_compact'), value: ReplyCardStyleSettings.STYLE_COMPACT },
    ]
  }

  static replyActionAlignmentOptions(motionHoldingHandSupported: boolean): SettingsOption[] {
    const options: SettingsOption[] = []
    if (motionHoldingHandSupported) {
      options.push({
        label: $r('app.string.smart_grip'),
        value: ReplyActionAlignmentSettings.MODE_SMART_GRIP,
      })
    }
    options.push(
      {
        label: $r('app.string.follow_operation'),
        value: ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION,
      },
      { label: $r('app.string.fixed_left'), value: ReplyActionAlignmentSettings.MODE_FIXED_LEFT },
      { label: $r('app.string.fixed_right'), value: ReplyActionAlignmentSettings.MODE_FIXED_RIGHT },
    )
    return options
  }

  static hotReplyMaxCountOptions(): SettingsOption[] {
    return [
      { label: SettingsPageCoordinator.hotReplyCountLabel(1), value: '1' },
      { label: SettingsPageCoordinator.hotReplyCountLabel(3), value: '3' },
      { label: SettingsPageCoordinator.hotReplyCountLabel(5), value: '5' },
      { label: SettingsPageCoordinator.hotReplyCountLabel(10), value: '10' },
    ]
  }

  static hotReplyMinThanksOptions(): SettingsOption[] {
    return [
      { label: SettingsPageCoordinator.hotReplyMinThanksLabel(1), value: '1' },
      { label: SettingsPageCoordinator.hotReplyMinThanksLabel(3), value: '3' },
      { label: SettingsPageCoordinator.hotReplyMinThanksLabel(5), value: '5' },
      { label: SettingsPageCoordinator.hotReplyMinThanksLabel(10), value: '10' },
      { label: SettingsPageCoordinator.hotReplyMinThanksLabel(20), value: '20' },
    ]
  }

  static base64DecodeModeOptions(): SettingsOption[] {
    return [
      { label: $r('app.string.common_closed'), value: ReadingSettings.BASE64_MODE_OFF },
      { label: $r('app.string.tap_to_view'), value: ReadingSettings.BASE64_MODE_BADGE },
      { label: $r('app.string.inline_display'), value: ReadingSettings.BASE64_MODE_INLINE },
    ]
  }


  static languageModeLabel(mode: string): ResourceStr {
    const normalizedMode = LanguageSettings.normalizeMode(mode)
    if (normalizedMode === LanguageSettings.MODE_ZH_CN) {
      return $r('app.string.language_simplified_chinese')
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_HK) {
      return $r('app.string.language_traditional_chinese_hk')
    }
    if (normalizedMode === LanguageSettings.MODE_ZH_TW) {
      return $r('app.string.language_traditional_chinese_tw')
    }
    if (normalizedMode === LanguageSettings.MODE_EN) {
      return $r('app.string.language_english')
    }
    if (normalizedMode === LanguageSettings.MODE_JA) {
      return $r('app.string.language_japanese')
    }
    if (normalizedMode === LanguageSettings.MODE_KO) {
      return $r('app.string.language_korean')
    }
    return $r('app.string.language_follow_system')
  }

  static themeModeLabel(mode: string): ResourceStr {
    const normalizedMode = ThemeSettings.normalizeMode(mode)
    if (normalizedMode === ThemeSettings.MODE_LIGHT) {
      return $r('app.string.common_light')
    }
    if (normalizedMode === ThemeSettings.MODE_DARK) {
      return $r('app.string.common_dark')
    }
    return $r('app.string.common_auto')
  }

  static themeColorLabel(color: string): ResourceStr {
    return ThemeColorSettings.label(color)
  }

  static themeColorValue(color: string): ResourceColor {
    return ThemeColorSettings.colorValue(color)
  }

  static immersiveMaterialLabel(level: string): ResourceStr {
    return ImmersiveMaterialSettings.label(level)
  }

  static avatarAppearanceLabel(appearance: string): ResourceStr {
    if (AvatarAppearanceSettings.normalize(appearance) === AvatarAppearanceSettings.APPEARANCE_SOFT) {
      return $r('app.string.avatar_appearance_soft')
    }
    return $r('app.string.avatar_appearance_circle')
  }

  static replyDisplayModeLabel(mode: string): ResourceStr {
    const value = ReplyDisplaySettings.normalizeMode(mode)
    if (value === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION) {
      return $r('app.string.threaded_at')
    }
    if (value === ReplyDisplaySettings.MODE_THREAD_REDUNDANT) {
      return $r('app.string.threaded_redundant')
    }
    if (value === ReplyDisplaySettings.MODE_OP) {
      return $r('app.string.op_only')
    }
    if (value === ReplyDisplaySettings.MODE_ORIGIN) {
      return $r('app.string.original')
    }
    return $r('app.string.threaded')
  }

  static replyCardStyleLabel(style: string): ResourceStr {
    if (ReplyCardStyleSettings.normalize(style) === ReplyCardStyleSettings.STYLE_COMPACT) {
      return $r('app.string.density_compact')
    }
    return $r('app.string.density_standard')
  }

  static replyActionAlignmentLabel(mode: string, smartGripSupported: boolean): ResourceStr {
    const effective = ReplyActionAlignmentSettings.effectiveMode(mode, smartGripSupported)
    if (effective === ReplyActionAlignmentSettings.MODE_SMART_GRIP) {
      return $r('app.string.smart_grip')
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_LEFT) {
      return $r('app.string.fixed_left')
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_RIGHT) {
      return $r('app.string.fixed_right')
    }
    return $r('app.string.follow_operation')
  }

  static hotReplyCountLabel(value: number): ResourceStr {
    const normalized = HotReplySettings.normalizeMaxCount(value)
    return AppStrings.format(
      AppStrings.text($r('app.string.hot_replies_count_format'), '{0} replies'),
      [`${normalized}`],
    )
  }

  static hotReplyMinThanksLabel(value: number): ResourceStr {
    const normalized = HotReplySettings.normalizeMinThanks(value)
    return AppStrings.format(
      AppStrings.text($r('app.string.hot_replies_min_thanks_format'), '{0} likes'),
      [`${normalized}`],
    )
  }


  static base64DecodeModeLabel(mode: string): ResourceStr {
    if (mode === ReadingSettings.BASE64_MODE_OFF) {
      return $r('app.string.common_closed')
    }
    if (mode === ReadingSettings.BASE64_MODE_INLINE) {
      return $r('app.string.inline_display')
    }
    return $r('app.string.tap_to_view')
  }

  static apiDomainLabel(baseUrl: string): string {
    return ApiDomainSettings.normalizeBaseUrl(baseUrl).replace(/^https:\/\//, '')
  }

}
