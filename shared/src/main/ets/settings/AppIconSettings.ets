import { bundleManager } from '@kit.AbilityKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import {
  APP_ICON_BLACK,
  APP_ICON_DEFAULT,
  connectAppIcon,
} from '../state/AppIconState'

export interface AppIconOption {
  label: ResourceStr
  value: string
  icon: ResourceStr
}

interface AppIconVariant {
  label: ResourceStr
  value: string
  icon: ResourceStr
}

/**
 * Launcher app-icon selection backed by HarmonyOS alternate icons (app.json5 `alternateIcons`
 * + bundleManager.setAlternateIcon, API 26+). The system state is the persisted source of truth;
 * this class only maps the app.json5 names to settings labels and previews.
 */
export class AppIconSettings {
  static isSupported(): boolean {
    return deviceInfo.apiAvailable('26.0.0')
  }

  private static variants(): AppIconVariant[] {
    return [
      {
        label: $r('app.string.app_icon_default'),
        value: APP_ICON_DEFAULT,
        icon: $r('app.media.app_icon'),
      },
      {
        label: $r('app.string.app_icon_sunset_solid'),
        value: 'sunset_solid',
        icon: $r('app.media.app_icon_sunset_solid'),
      },
      {
        label: $r('app.string.app_icon_sunset_glass'),
        value: 'sunset_glass',
        icon: $r('app.media.app_icon_sunset_glass'),
      },
      {
        label: $r('app.string.app_icon_coral_solid'),
        value: 'coral_solid',
        icon: $r('app.media.app_icon_coral_solid'),
      },
      {
        label: $r('app.string.app_icon_coral_glass'),
        value: 'coral_glass',
        icon: $r('app.media.app_icon_coral_glass'),
      },
      {
        label: $r('app.string.app_icon_emerald_solid'),
        value: 'emerald_solid',
        icon: $r('app.media.app_icon_emerald_solid'),
      },
      {
        label: $r('app.string.app_icon_emerald_glass'),
        value: 'emerald_glass',
        icon: $r('app.media.app_icon_emerald_glass'),
      },
      {
        label: $r('app.string.app_icon_azure_solid'),
        value: 'azure_solid',
        icon: $r('app.media.app_icon_azure_solid'),
      },
      {
        label: $r('app.string.app_icon_azure_glass'),
        value: 'azure_glass',
        icon: $r('app.media.app_icon_azure_glass'),
      },
      {
        label: $r('app.string.app_icon_cyan_solid'),
        value: 'cyan_solid',
        icon: $r('app.media.app_icon_cyan_solid'),
      },
      {
        label: $r('app.string.app_icon_cyan_glass'),
        value: 'cyan_glass',
        icon: $r('app.media.app_icon_cyan_glass'),
      },
      {
        label: $r('app.string.app_icon_slate_solid'),
        value: 'slate_solid',
        icon: $r('app.media.app_icon_slate_solid'),
      },
      {
        label: $r('app.string.app_icon_slate_glass'),
        value: 'slate_glass',
        icon: $r('app.media.app_icon_slate_glass'),
      },
      {
        label: $r('app.string.app_icon_black'),
        value: APP_ICON_BLACK,
        icon: $r('app.media.app_icon_black_solid'),
      },
    ]
  }

  private static findVariant(name: string): AppIconVariant {
    const normalized = (name || '').trim()
    const variants = AppIconSettings.variants()
    for (const variant of variants) {
      if (variant.value === normalized) {
        return variant
      }
    }
    // Legacy value written before the icon names followed the resource naming convention.
    if (normalized === 'black') {
      for (const variant of variants) {
        if (variant.value === APP_ICON_BLACK) {
          return variant
        }
      }
    }
    return variants[0]
  }

  static normalizeName(name: string): string {
    return AppIconSettings.findVariant(name).value
  }

  static options(): AppIconOption[] {
    const options: AppIconOption[] = []
    for (const variant of AppIconSettings.variants()) {
      options.push({ label: variant.label, value: variant.value, icon: variant.icon })
    }
    return options
  }

  static label(name: string): ResourceStr {
    return AppIconSettings.findVariant(name).label
  }

  static apply(name: string): void {
    connectAppIcon().name = AppIconSettings.normalizeName(name)
  }

  static async load(): Promise<void> {
    if (!AppIconSettings.isSupported()) {
      AppIconSettings.apply(APP_ICON_DEFAULT)
      return
    }
    try {
      const icons = await bundleManager.getAlternateIcons()
      const enabled = icons.find((icon: bundleManager.AlternateIconInfo) => icon.enabled)
      AppIconSettings.apply(enabled ? enabled.iconName : APP_ICON_DEFAULT)
    } catch (error) {
      // Keep the current mirror value: a transient query failure must not reset the visible choice.
      const e = error as Error
      console.error('load app icon state failed: ' + e.message)
    }
  }

  /** Switches the launcher icon. Default is applied by cancelling the alternate icon (''). */
  static async set(name: string): Promise<void> {
    if (!AppIconSettings.isSupported()) {
      throw new Error('Alternate app icons require API 26')
    }
    const normalized = AppIconSettings.normalizeName(name)
    await bundleManager.setAlternateIcon(normalized === APP_ICON_DEFAULT ? '' : normalized)
    AppIconSettings.apply(normalized)
  }
}
