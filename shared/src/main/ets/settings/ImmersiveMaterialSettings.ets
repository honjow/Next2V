import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { hdsMaterial } from '@kit.UIDesignKit'
import { StorageKeys } from '../constants/StorageKeys'
import { connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_LEVEL: string = StorageKeys.IMMERSIVE_MATERIAL_LEVEL
const LEVEL_ADAPTIVE: string = 'adaptive'
const LEVEL_EXQUISITE: string = 'exquisite'
const LEVEL_GENTLE: string = 'gentle'
const LEVEL_SMOOTH: string = 'smooth'

export interface ImmersiveMaterialOption {
  label: ResourceStr
  value: string
}

export interface ImmersiveMaterialSettingsSnapshot {
  level: string
}

export interface ImmersiveMaterialEffect {
  materialType: hdsMaterial.MaterialType
  materialLevel: hdsMaterial.MaterialLevel
}

export class ImmersiveMaterialSettings {
  static readonly LEVEL_ADAPTIVE: string = LEVEL_ADAPTIVE
  static readonly LEVEL_EXQUISITE: string = LEVEL_EXQUISITE
  static readonly LEVEL_GENTLE: string = LEVEL_GENTLE
  static readonly LEVEL_SMOOTH: string = LEVEL_SMOOTH
  static readonly DEFAULT_LEVEL: string = LEVEL_ADAPTIVE

  static options(): ImmersiveMaterialOption[] {
    const options: ImmersiveMaterialOption[] = [
      { label: $r('app.string.common_auto'), value: LEVEL_ADAPTIVE },
    ]
    if (ImmersiveMaterialSettings.immersiveSupported()) {
      options.push(
        { label: $r('app.string.immersive_material_exquisite'), value: LEVEL_EXQUISITE },
        { label: $r('app.string.immersive_material_gentle'), value: LEVEL_GENTLE },
        { label: $r('app.string.immersive_material_smooth'), value: LEVEL_SMOOTH },
      )
    }
    return options
  }

  static immersiveSupported(): boolean {
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes()
      for (let i = 0; i < types.length; i++) {
        if (types[i] === hdsMaterial.MaterialType.IMMERSIVE) {
          return true
        }
      }
      return false
    } catch (_error) {
      return true
    }
  }

  static apply(level: string): ImmersiveMaterialSettingsSnapshot {
    const normalized = ImmersiveMaterialSettings.normalizeLevel(level)
    setAppStorageValue<string>(KEY_LEVEL, normalized)
    connectImmersiveMaterialSettings().level = normalized
    return { level: normalized }
  }

  static async load(context: common.UIAbilityContext): Promise<ImmersiveMaterialSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ImmersiveMaterialSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read immersive material settings')
    }
  }

  static async loadFromStore(
    store: SettingsPreferencesStore,
  ): Promise<ImmersiveMaterialSettingsSnapshot> {
    const level = ImmersiveMaterialSettings.normalizeLevel(
      store.getSync(KEY_LEVEL, LEVEL_ADAPTIVE) as string,
    )
    return ImmersiveMaterialSettings.apply(level)
  }

  static async save(context: common.UIAbilityContext, level: string): Promise<void> {
    const normalized = ImmersiveMaterialSettings.normalizeLevel(level)
    ImmersiveMaterialSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LEVEL, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save immersive material settings')
    }
  }

  static normalizeLevel(level: string): string {
    const value = (level || '').trim()
    if (value === LEVEL_EXQUISITE || value === LEVEL_GENTLE || value === LEVEL_SMOOTH) {
      return value
    }
    return LEVEL_ADAPTIVE
  }

  static label(level: string): ResourceStr {
    const normalized = ImmersiveMaterialSettings.normalizeLevel(level)
    if (normalized === LEVEL_EXQUISITE) {
      return $r('app.string.immersive_material_exquisite')
    }
    if (normalized === LEVEL_GENTLE) {
      return $r('app.string.immersive_material_gentle')
    }
    if (normalized === LEVEL_SMOOTH) {
      return $r('app.string.immersive_material_smooth')
    }
    return $r('app.string.common_auto')
  }

  static effect(level: string): ImmersiveMaterialEffect {
    const normalized = ImmersiveMaterialSettings.normalizeLevel(level)
    if (!ImmersiveMaterialSettings.immersiveSupported()) {
      return {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      }
    }
    if (normalized === LEVEL_EXQUISITE) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE,
      }
    }
    if (normalized === LEVEL_GENTLE) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.GENTLE,
      }
    }
    if (normalized === LEVEL_SMOOTH) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH,
      }
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
    }
  }

  static systemMaterial(
    level: string,
    adaptiveStyle: uiMaterial.ImmersiveStyle,
    interactive: boolean,
  ): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined
    }
    return new uiMaterial.ImmersiveMaterial({
      style: ImmersiveMaterialSettings.systemMaterialStyle(level, adaptiveStyle),
      colorInvert: true,
      applyShadow: true,
      interactive: interactive,
    })
  }

  private static systemMaterialStyle(
    level: string,
    adaptiveStyle: uiMaterial.ImmersiveStyle,
  ): uiMaterial.ImmersiveStyle {
    const normalized = ImmersiveMaterialSettings.normalizeLevel(level)
    if (normalized === LEVEL_EXQUISITE) {
      return uiMaterial.ImmersiveStyle.THIN
    }
    if (normalized === LEVEL_GENTLE) {
      return uiMaterial.ImmersiveStyle.REGULAR
    }
    if (normalized === LEVEL_SMOOTH) {
      return uiMaterial.ImmersiveStyle.THICK
    }
    return adaptiveStyle
  }
}
