import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'
import { connectDiagnostics } from '../state/DiagnosticsState'

export interface DiagnosticsSettingsSnapshot {
  enabled: boolean
  minLevel: string
}

export class DiagnosticsSettings {
  static readonly LEVEL_DEBUG: string = 'debug'
  static readonly LEVEL_INFO: string = 'info'
  static readonly LEVEL_WARN: string = 'warn'
  static readonly LEVEL_ERROR: string = 'error'
  static readonly DEFAULT_ENABLED: boolean = true
  static readonly DEFAULT_MIN_LEVEL: string = DiagnosticsSettings.LEVEL_INFO

  static apply(enabled: boolean, minLevel: string = DiagnosticsSettings.DEFAULT_MIN_LEVEL): void {
    const safeLevel = DiagnosticsSettings.normalizeLevel(minLevel)
    setAppStorageValue<boolean>(StorageKeys.DIAGNOSTICS_ENABLED, enabled)
    setAppStorageValue<string>(StorageKeys.DIAGNOSTICS_MIN_LEVEL, safeLevel)
    // V2 mirror dual-write for @ComponentV2 readers (DiagnosticsLogPage) and the getters below.
    const state = connectDiagnostics()
    state.enabled = enabled
    state.minLevel = safeLevel
    DiagnosticLogger.configure(enabled, safeLevel)
  }

  static isEnabled(): boolean {
    // Read the V2 mirror kept in lockstep by apply() (the single chokepoint). Default DEFAULT_ENABLED.
    return connectDiagnostics().enabled
  }

  static minLevel(): string {
    // Read the V2 mirror kept in lockstep by apply() (the single chokepoint). Default DEFAULT_MIN_LEVEL.
    return connectDiagnostics().minLevel
  }

  static async load(context: common.UIAbilityContext): Promise<DiagnosticsSettingsSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    return DiagnosticsSettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<DiagnosticsSettingsSnapshot> {
    const enabled = store.getSync(StorageKeys.DIAGNOSTICS_ENABLED, DiagnosticsSettings.DEFAULT_ENABLED) as boolean
    const minLevel = DiagnosticsSettings.normalizeLevel(
      store.getSync(StorageKeys.DIAGNOSTICS_MIN_LEVEL, DiagnosticsSettings.DEFAULT_MIN_LEVEL) as string
    )
    DiagnosticsSettings.apply(enabled, minLevel)
    DiagnosticLogger.info('diagnostics', 'diagnostics_setting_loaded', { enabled: enabled, minLevel: minLevel })
    return { enabled: enabled, minLevel: minLevel }
  }

  static async save(context: common.UIAbilityContext, enabled: boolean, minLevel: string = DiagnosticsSettings.minLevel()): Promise<void> {
    const safeLevel = DiagnosticsSettings.normalizeLevel(minLevel)
    DiagnosticsSettings.apply(enabled, safeLevel)
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    store.putSync(StorageKeys.DIAGNOSTICS_ENABLED, enabled)
    store.putSync(StorageKeys.DIAGNOSTICS_MIN_LEVEL, safeLevel)
    store.flushSync()
    DiagnosticLogger.info('diagnostics', 'diagnostics_setting_saved', { enabled: enabled, minLevel: safeLevel })
  }

  static exportText(): string {
    return DiagnosticLogger.exportText()
  }

  static count(): number {
    return DiagnosticLogger.count()
  }

  static clearLogs(): void {
    DiagnosticLogger.clear()
    DiagnosticLogger.info('diagnostics', 'diagnostics_logs_cleared', {})
  }

  static normalizeLevel(level: string): string {
    if (level === DiagnosticsSettings.LEVEL_DEBUG || level === DiagnosticsSettings.LEVEL_INFO ||
      level === DiagnosticsSettings.LEVEL_WARN || level === DiagnosticsSettings.LEVEL_ERROR) {
      return level
    }
    return DiagnosticsSettings.DEFAULT_MIN_LEVEL
  }
}
