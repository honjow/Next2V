import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

const STORE_NAME: string = 'next2v_settings'
const KEY_FONT_SIZE: string = 'readingFontSize'
const KEY_LINE_HEIGHT: string = 'readingLineHeight'
const KEY_DENSITY: string = 'readingDensity'
const KEY_RESTORE_POSITION: string = 'readingRestorePosition'
const DENSITY_COMPACT: string = 'compact'
const DENSITY_STANDARD: string = 'standard'
const DENSITY_COMFORTABLE: string = 'comfortable'

export interface ReadingSettingsSnapshot {
  fontSize: number
  lineHeight: number
  density: string
  restorePosition: boolean
}

export class ReadingSettings {
  static readonly FONT_SIZE_MIN: number = 12
  static readonly FONT_SIZE_MAX: number = 18
  static readonly LINE_HEIGHT_MIN: number = 18
  static readonly LINE_HEIGHT_MAX: number = 30
  static readonly DENSITY_COMPACT: string = DENSITY_COMPACT
  static readonly DENSITY_STANDARD: string = DENSITY_STANDARD
  static readonly DENSITY_COMFORTABLE: string = DENSITY_COMFORTABLE

  static apply(fontSize: number, lineHeight: number, density: string, restorePosition: boolean = false): void {
    const normalizedFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedFontSize)
    ReadingSettings.setAppStorageValue<number>(StorageKeys.READING_FONT_SIZE, normalizedFontSize)
    ReadingSettings.setAppStorageValue<number>(StorageKeys.READING_LINE_HEIGHT, normalizedLineHeight)
    ReadingSettings.setAppStorageValue<string>(StorageKeys.READING_DENSITY, ReadingSettings.normalizeDensity(density))
    ReadingSettings.setAppStorageValue<boolean>(StorageKeys.READING_RESTORE_POSITION, restorePosition)
  }

  static async load(context: common.UIAbilityContext): Promise<ReadingSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const fontSize = ReadingSettings.normalizeFontSize(store.getSync(KEY_FONT_SIZE, ThemeConstants.FONT_SIZE_BODY) as number)
      const lineHeight = ReadingSettings.normalizeLineHeight(store.getSync(KEY_LINE_HEIGHT, ThemeConstants.LINE_HEIGHT_BODY) as number, fontSize)
      const density = ReadingSettings.normalizeDensity(store.getSync(KEY_DENSITY, DENSITY_STANDARD) as string)
      const restorePosition = store.getSync(KEY_RESTORE_POSITION, false) as boolean
      ReadingSettings.apply(fontSize, lineHeight, density, restorePosition)
      return { fontSize: fontSize, lineHeight: lineHeight, density: density, restorePosition: restorePosition }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取阅读设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, fontSize: number, lineHeight: number, density: string): Promise<void> {
    const normalizedFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedFontSize)
    const normalizedDensity = ReadingSettings.normalizeDensity(density)
    const currentRestorePosition = AppStorage.get<boolean>(StorageKeys.READING_RESTORE_POSITION) ?? false
    ReadingSettings.apply(normalizedFontSize, normalizedLineHeight, normalizedDensity, currentRestorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_FONT_SIZE, normalizedFontSize)
      store.putSync(KEY_LINE_HEIGHT, normalizedLineHeight)
      store.putSync(KEY_DENSITY, normalizedDensity)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读设置失败')
    }
  }

  static async saveTypography(context: common.UIAbilityContext, fontSize: number, lineHeight: number): Promise<void> {
    const normalizedFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedFontSize)
    const currentDensity = ReadingSettings.normalizeDensity(
      AppStorage.get<string>(StorageKeys.READING_DENSITY) ?? DENSITY_STANDARD)
    const currentRestorePosition = AppStorage.get<boolean>(StorageKeys.READING_RESTORE_POSITION) ?? false
    ReadingSettings.apply(normalizedFontSize, normalizedLineHeight, currentDensity, currentRestorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_FONT_SIZE, normalizedFontSize)
      store.putSync(KEY_LINE_HEIGHT, normalizedLineHeight)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读设置失败')
    }
  }

  static async saveRestorePosition(context: common.UIAbilityContext, restorePosition: boolean): Promise<void> {
    ReadingSettings.setAppStorageValue<boolean>(StorageKeys.READING_RESTORE_POSITION, restorePosition)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_RESTORE_POSITION, restorePosition)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读位置设置失败')
    }
  }

  static normalizeFontSize(value: number): number {
    const size = Math.round(value)
    if (isNaN(size)) {
      return ThemeConstants.FONT_SIZE_BODY
    }
    if (size < ReadingSettings.FONT_SIZE_MIN) {
      return ReadingSettings.FONT_SIZE_MIN
    }
    if (size > ReadingSettings.FONT_SIZE_MAX) {
      return ReadingSettings.FONT_SIZE_MAX
    }
    return size
  }

  static normalizeLineHeight(value: number, fontSize: number = ThemeConstants.FONT_SIZE_BODY): number {
    const min = Math.max(ReadingSettings.LINE_HEIGHT_MIN, ReadingSettings.normalizeFontSize(fontSize) + 4)
    const lineHeight = Math.round(value)
    if (isNaN(lineHeight)) {
      return ThemeConstants.LINE_HEIGHT_BODY
    }
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

  private static setAppStorageValue<T>(key: string, value: T): void {
    if (!AppStorage.set<T>(key, value)) {
      AppStorage.setOrCreate<T>(key, value)
    }
  }
}
