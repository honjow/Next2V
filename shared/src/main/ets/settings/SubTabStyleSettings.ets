import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import {
  connectSubTabStyle,
  SUBTAB_STYLE_CAPSULE,
  SUBTAB_STYLE_DEFAULT,
  SUBTAB_STYLE_UNDERLINE,
} from '../state/SubTabStyleState'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'

export interface SubTabStyleOption {
  label: ResourceStr
  style: string
}

/**
 * Shared appearance for sub-tab bars (currently the home feed tab bar).
 * Ported from the NextE shared implementation (erosTeam/NextE#8 capsule sub-tabs, maintainer
 * commit ebd3f4b3), adapted to V2Next: the resource-free label() form (the settings row is
 * AppStrings-based). Default style is capsule (V2Next decision of 2026-10-19, matching NextE's
 * default); a saved underline/capsule preference overrides it and survives startup.
 */
export class SubTabStyleSettings {
  static isCapsule(style: string): boolean {
    return SubTabStyleSettings.normalizeStyle(style) === SUBTAB_STYLE_CAPSULE
  }

  static normalizeStyle(style: string): string {
    const normalized: string = (style || '').trim()
    // Recognize BOTH explicit values, then fall back to the default. NextE's original one-liner
    // (underline ? underline : DEFAULT) silently collapsed capsule into the default; that was
    // safe only because NextE's default IS capsule. V2Next's default is underline, so a bare
    // capsule selection would normalize back to underline and the capsule setting could never
    // stick (device-verified on 192.168.50.237). An explicit saved capsule/underline must
    // survive startup, so the two real values must be preserved, not folded to the default.
    if (normalized === SUBTAB_STYLE_CAPSULE) {
      return SUBTAB_STYLE_CAPSULE
    }
    if (normalized === SUBTAB_STYLE_UNDERLINE) {
      return SUBTAB_STYLE_UNDERLINE
    }
    return SUBTAB_STYLE_DEFAULT
  }

  static options(): SubTabStyleOption[] {
    return [
      { label: $r('app.string.subtab_style_underline'), style: SUBTAB_STYLE_UNDERLINE },
      { label: $r('app.string.subtab_style_capsule'), style: SUBTAB_STYLE_CAPSULE },
    ]
  }

  // Resource-free label for the settings row trailing text, matching V2Next's AppStrings pattern
  // (the settings rows take plain strings; AppStrings.text() registers the locale signal for refresh).
  static label(style: string): string {
    return SubTabStyleSettings.isCapsule(style)
      ? AppStrings.text($r('app.string.subtab_style_capsule'), 'Capsule')
      : AppStrings.text($r('app.string.subtab_style_underline'), 'Underline')
  }

  static apply(style: string): void {
    connectSubTabStyle().style = SubTabStyleSettings.normalizeStyle(style)
  }

  static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
      SubTabStyleSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read sub-tab style settings')
    }
  }

  static loadFromStore(store: SettingsPreferencesStore): void {
    const style = SubTabStyleSettings.normalizeStyle(
      store.getSync(StorageKeys.SUBTAB_STYLE, SUBTAB_STYLE_DEFAULT) as string,
    )
    SubTabStyleSettings.apply(style)
  }

  static async save(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized = SubTabStyleSettings.normalizeStyle(style)
    SubTabStyleSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
      store.putSync(StorageKeys.SUBTAB_STYLE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save sub-tab style settings')
    }
  }
}
