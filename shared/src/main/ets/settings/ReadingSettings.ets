import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'

const STORE_NAME: string = 'next2v_settings'
const KEY_FONT_SIZE: string = 'readingFontSize'
const KEY_LINE_HEIGHT: string = 'readingLineHeight'
const KEY_DENSITY: string = 'readingDensity'
const DENSITY_COMPACT: string = 'compact'
const DENSITY_STANDARD: string = 'standard'
const DENSITY_COMFORTABLE: string = 'comfortable'

export interface ReadingSettingsSnapshot {
  fontSize: number
  lineHeight: number
  density: string
}

export class ReadingSettings {
  static readonly FONT_SIZE_MIN: number = 12
  static readonly FONT_SIZE_MAX: number = 18
  static readonly LINE_HEIGHT_MIN: number = 18
  static readonly LINE_HEIGHT_MAX: number = 30
  static readonly DENSITY_COMPACT: string = DENSITY_COMPACT
  static readonly DENSITY_STANDARD: string = DENSITY_STANDARD
  static readonly DENSITY_COMFORTABLE: string = DENSITY_COMFORTABLE

  static apply(fontSize: number, lineHeight: number, density: string): void {
    const normalizedFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedFontSize)
    AppStorage.setOrCreate<number>(StorageKeys.READING_FONT_SIZE, normalizedFontSize)
    AppStorage.setOrCreate<number>(StorageKeys.READING_LINE_HEIGHT, normalizedLineHeight)
    AppStorage.setOrCreate<string>(StorageKeys.READING_DENSITY, ReadingSettings.normalizeDensity(density))
  }

  static async load(context: common.UIAbilityContext): Promise<ReadingSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const fontSize = ReadingSettings.normalizeFontSize(store.getSync(KEY_FONT_SIZE, ThemeConstants.FONT_SIZE_BODY) as number)
      const lineHeight = ReadingSettings.normalizeLineHeight(store.getSync(KEY_LINE_HEIGHT, ThemeConstants.LINE_HEIGHT_BODY) as number, fontSize)
      const density = ReadingSettings.normalizeDensity(store.getSync(KEY_DENSITY, DENSITY_STANDARD) as string)
      ReadingSettings.apply(fontSize, lineHeight, density)
      return { fontSize: fontSize, lineHeight: lineHeight, density: density }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取阅读设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, fontSize: number, lineHeight: number, density: string): Promise<void> {
    const normalizedFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const normalizedLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, normalizedFontSize)
    const normalizedDensity = ReadingSettings.normalizeDensity(density)
    ReadingSettings.apply(normalizedFontSize, normalizedLineHeight, normalizedDensity)
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
}
