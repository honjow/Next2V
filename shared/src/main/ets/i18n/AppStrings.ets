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

  static setOverrideLocaleForLanguageMode(mode: string): void {
    const locale = AppStrings.overrideLocaleForMode(mode)
    if (!locale || !AppStrings.context) {
      AppStrings.overrideResMgr = null
      return
    }
    try {
      const config = AppStrings.context.resourceManager.getOverrideConfiguration()
      config.locale = locale
      AppStrings.overrideResMgr = AppStrings.context.resourceManager.getOverrideResourceManager(config)
    } catch (_error) {
      AppStrings.overrideResMgr = null
    }
  }

  private static overrideLocaleForMode(mode: string): string {
    if (mode === 'zh-Hans') {
      return 'zh-Hans-CN'
    }
    if (mode === 'zh-Hant-HK') {
      return 'zh-Hant-HK'
    }
    if (mode === 'zh-Hant-TW') {
      return 'zh-Hant-TW'
    }
    if (mode === 'en-US') {
      return 'en-US'
    }
    if (mode === 'ja-JP') {
      return 'ja-JP'
    }
    if (mode === 'ko-KR') {
      return 'ko-KR'
    }
    return ''
  }
}
