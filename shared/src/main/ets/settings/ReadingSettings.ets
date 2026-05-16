import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_TEXT_SCALE: string = StorageKeys.READING_TEXT_SCALE
const KEY_LINE_HEIGHT: string = StorageKeys.READING_LINE_HEIGHT
const KEY_DENSITY: string = StorageKeys.READING_DENSITY
const KEY_RESTORE_POSITION: string = StorageKeys.READING_RESTORE_POSITION
const KEY_BASE64_DECODE_MODE: string = StorageKeys.READING_BASE64_DECODE_MODE
const DENSITY_COMPACT: string = 'compact'
const DENSITY_STANDARD: string = 'standard'
const DENSITY_COMFORTABLE: string = 'comfortable'
const BASE64_MODE_OFF: string = 'off'
const BASE64_MODE_BADGE: string = 'badge'
const BASE64_MODE_INLINE: string = 'inline'

export interface ReadingSettingsSnapshot {
  textScale: number
  lineHeight: number
  density: string
  restorePosition: boolean
  base64DecodeMode: string
}

export class ReadingSettings {
  static readonly TEXT_SCALE_DEFAULT: number = 1.0
  static readonly TEXT_SCALE_MIN: number = 12 / ThemeConstants.FONT_SIZE_BODY
  static readonly TEXT_SCALE_MAX: number = 18 / ThemeConstants.FONT_SIZE_BODY
  static readonly LINE_HEIGHT_MIN: number = 18
  static readonly LINE_HEIGHT_MAX: number = 30
  static readonly DENSITY_COMPACT: string = DENSITY_COMPACT
  static readonly DENSITY_STANDARD: string = DENSITY_STANDARD
  static readonly DENSITY_COMFORTABLE: string = DENSITY_COMFORTABLE
  static readonly BASE64_MODE_OFF: string = BASE64_MODE_OFF
  static readonly BASE64_MODE_BADGE: string = BASE64_MODE_BADGE
  static readonly BASE64_MODE_INLINE: string = BASE64_MODE_INLINE

  static apply(textScaleSource: number, lineHeight: number, density: string, restorePosition: boolean = false): void {
    const normalizedTextScale = ReadingSettings.normalizeTextScale(textScaleSource)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedTextScale)
    setAppStorageValue<number>(StorageKeys.READING_TEXT_SCALE, normalizedTextScale)
    setAppStorageValue<number>(StorageKeys.READING_LINE_HEIGHT, normalizedLineHeight)
    setAppStorageValue<string>(StorageKeys.READING_DENSITY, ReadingSettings.normalizeDensity(density))
    setAppStorageValue<boolean>(StorageKeys.READING_RESTORE_POSITION, restorePosition)
    setAppStorageValue<string>(StorageKeys.READING_BASE64_DECODE_MODE,
      ReadingSettings.normalizeBase64DecodeMode(AppStorage.get<string>(StorageKeys.READING_BASE64_DECODE_MODE) ?? BASE64_MODE_BADGE))
  }

  static async load(context: common.UIAbilityContext): Promise<ReadingSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ReadingSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取阅读设置失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<ReadingSettingsSnapshot> {
    const textScale = ReadingSettings.normalizeTextScale(store.getSync(KEY_TEXT_SCALE, ReadingSettings.TEXT_SCALE_DEFAULT) as number)
    const lineHeight = ReadingSettings.normalizeLineHeight(store.getSync(KEY_LINE_HEIGHT, ThemeConstants.LINE_HEIGHT_BODY) as number, textScale)
    const density = ReadingSettings.normalizeDensity(store.getSync(KEY_DENSITY, DENSITY_STANDARD) as string)
    const restorePosition = store.getSync(KEY_RESTORE_POSITION, false) as boolean
    const base64DecodeMode = ReadingSettings.normalizeBase64DecodeMode(store.getSync(KEY_BASE64_DECODE_MODE, BASE64_MODE_BADGE) as string)
    ReadingSettings.apply(textScale, lineHeight, density, restorePosition)
    setAppStorageValue<string>(StorageKeys.READING_BASE64_DECODE_MODE, base64DecodeMode)
    return {
      textScale: textScale,
      lineHeight: lineHeight,
      density: density,
      restorePosition: restorePosition,
      base64DecodeMode: base64DecodeMode,
    }
  }

  static async save(context: common.UIAbilityContext, textScaleSource: number, lineHeight: number, density: string): Promise<void> {
    const normalizedTextScale = ReadingSettings.normalizeTextScale(textScaleSource)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedTextScale)
    const normalizedDensity = ReadingSettings.normalizeDensity(density)
    const currentRestorePosition = AppStorage.get<boolean>(StorageKeys.READING_RESTORE_POSITION) ?? false
    ReadingSettings.apply(normalizedTextScale, normalizedLineHeight, normalizedDensity, currentRestorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TEXT_SCALE, normalizedTextScale)
      store.putSync(KEY_LINE_HEIGHT, normalizedLineHeight)
      store.putSync(KEY_DENSITY, normalizedDensity)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读设置失败')
    }
  }

  static async saveTypography(context: common.UIAbilityContext, textScaleSource: number, lineHeight: number): Promise<void> {
    const normalizedTextScale = ReadingSettings.normalizeTextScale(textScaleSource)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedTextScale)
    const currentDensity = ReadingSettings.normalizeDensity(
      AppStorage.get<string>(StorageKeys.READING_DENSITY) ?? DENSITY_STANDARD)
    const currentRestorePosition = AppStorage.get<boolean>(StorageKeys.READING_RESTORE_POSITION) ?? false
    ReadingSettings.apply(normalizedTextScale, normalizedLineHeight, currentDensity, currentRestorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TEXT_SCALE, normalizedTextScale)
      store.putSync(KEY_LINE_HEIGHT, normalizedLineHeight)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读设置失败')
    }
  }

  static async saveRestorePosition(context: common.UIAbilityContext, restorePosition: boolean): Promise<void> {
    setAppStorageValue<boolean>(StorageKeys.READING_RESTORE_POSITION, restorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_RESTORE_POSITION, restorePosition)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读位置设置失败')
    }
  }

  static async saveBase64DecodeMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized = ReadingSettings.normalizeBase64DecodeMode(mode)
    setAppStorageValue<string>(StorageKeys.READING_BASE64_DECODE_MODE, normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_BASE64_DECODE_MODE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存 Base64 解码设置失败')
    }
  }

  static normalizeTextScale(value: number): number {
    const numeric = Number(value)
    if (!Number.isFinite(numeric)) {
      return ReadingSettings.TEXT_SCALE_DEFAULT
    }
    const scale = numeric
    if (scale < ReadingSettings.TEXT_SCALE_MIN) {
      return ReadingSettings.TEXT_SCALE_MIN
    }
    if (scale > ReadingSettings.TEXT_SCALE_MAX) {
      return ReadingSettings.TEXT_SCALE_MAX
    }
    return Math.round(scale * 100) / 100
  }

  static scaleTypographyToken(baseValue: number, textScaleSource: number): number {
    return Math.round(baseValue * ReadingSettings.normalizeTextScale(textScaleSource))
  }

  static normalizeLineHeight(value: number, textScaleSource: number = ReadingSettings.TEXT_SCALE_DEFAULT): number {
    const textScale = ReadingSettings.normalizeTextScale(textScaleSource)
    const scaledDefaultLineHeight = ReadingSettings.scaleTypographyToken(ThemeConstants.LINE_HEIGHT_BODY, textScale)
    const lineHeight = Math.round(value)
    if (isNaN(lineHeight)) {
      return scaledDefaultLineHeight
    }
    const min = Math.max(ReadingSettings.LINE_HEIGHT_MIN, scaledDefaultLineHeight)
    if (lineHeight < min) {
      return min
    }
    if (lineHeight > ReadingSettings.LINE_HEIGHT_MAX) {
      return ReadingSettings.LINE_HEIGHT_MAX
    }
    return lineHeight
  }

  static normalizeDensity(value: string): string {
    const density = (value || '').trim()
    if (density === DENSITY_COMPACT || density === DENSITY_COMFORTABLE) {
      return density
    }
    return DENSITY_STANDARD
  }

  static normalizeBase64DecodeMode(value: string): string {
    const mode = (value || '').trim()
    if (mode === BASE64_MODE_OFF || mode === BASE64_MODE_INLINE) {
      return mode
    }
    return BASE64_MODE_BADGE
  }
}
