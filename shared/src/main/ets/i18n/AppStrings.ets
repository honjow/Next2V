import { common } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'

export type AppLanguageMode = 'default' | 'zh-Hans' | 'zh-Hant-HK' | 'zh-Hant-TW' | 'en-US' | 'ja-JP' | 'ko-KR'

export class AppStrings {
  static readonly DEFAULT_LANGUAGE_MODE: AppLanguageMode = 'default'
  static readonly SUPPORTED_LOCALES: string[] = ['default', 'zh-Hans', 'zh-Hant-HK', 'zh-Hant-TW', 'en-US', 'ja-JP', 'ko-KR']
  private static context: common.UIAbilityContext | null = null
  private static overrideResMgr: resourceManager.ResourceManager | null = null

  static init(context: common.UIAbilityContext): void {
    AppStrings.context = context
  }

  static format(template: string, values: string[]): string {
    let text = template
    values.forEach((value: string, index: number) => {
      text = text.split(`{${index}}`).join(value)
    })
    return text
  }

  /**
   * Resolve a localized string for the given Resource.
   *
   * Explicit app language modes resolve through an override ResourceManager
   * seeded by LanguageSettings.apply(). Follow-system mode resolves through
   * the default ResourceManager on the UIAbility context.
   */
  static text(resource: Resource, fallback: string): string {
    // Prefer the override resource manager so explicit language changes can
    // resolve through Harmony resources without waiting for a cold start.
    if (AppStrings.overrideResMgr) {
      try {
        return AppStrings.overrideResMgr.getStringSync(resource.id) || fallback
      } catch (_error) {
        // Fall through to the default resource manager path.
      }
    }

    // Fallback: use the default ResourceManager. This is correct for
    // follow-system mode and also keeps a safety net if override creation fails.
    try {
      const resourceSource = AppStrings.context?.resourceManager
      if (!resourceSource) {
        return fallback
      }
      return resourceSource.getStringSync(resource) || fallback
    } catch (_error) {
      return fallback
    }
  }

  static setOverrideLocaleForLanguageMode(mode: string, resolvedLanguage: string): string {
    const locale = AppStrings.overrideLocaleForMode(mode) || AppStrings.overrideLocaleForMode(resolvedLanguage)
    if (!locale || !AppStrings.context) {
      AppStrings.overrideResMgr = null
      return locale
    }
    try {
      const config = AppStrings.context.resourceManager.getOverrideConfiguration()
      config.locale = locale
      AppStrings.context.resourceManager.updateOverrideConfiguration(config)
      AppStrings.overrideResMgr = AppStrings.context.resourceManager.getOverrideResourceManager(config)
    } catch (_error) {
      AppStrings.overrideResMgr = null
    }
    return locale
  }

  private static overrideLocaleForMode(mode: string): string {
    const normalized = (mode || '').trim()
    if (normalized === 'zh-Hans' || normalized === 'zh-CN' || normalized === 'zh' ||
      normalized.indexOf('zh-Hans') === 0) {
      return 'zh-Hans-CN'
    }
    if (normalized === 'zh-Hant-HK' || normalized === 'zh-HK' ||
      normalized.indexOf('zh-Hant-HK') === 0) {
      return 'zh-Hant-HK'
    }
    if (normalized === 'zh-Hant-TW' || normalized === 'zh-TW' ||
      normalized.indexOf('zh-Hant-TW') === 0) {
      return 'zh-Hant-TW'
    }
    if (normalized === 'en-US' || normalized === 'en' || normalized.indexOf('en-') === 0) {
      return 'en-US'
    }
    if (normalized === 'ja-JP' || normalized === 'ja' || normalized.indexOf('ja-') === 0) {
      return 'ja-JP'
    }
    if (normalized === 'ko-KR' || normalized === 'ko' || normalized.indexOf('ko-') === 0) {
      return 'ko-KR'
    }
    return ''
  }
}
