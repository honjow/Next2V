import { common } from '@kit.AbilityKit'
import { DiagnosticsRedactor, DiagnosticContextObject, DiagnosticLogEntry } from './DiagnosticsRedactor'
import { DiagnosticsLogFileSink } from './DiagnosticsLogFileSink'
import { DiagnosticsStore } from './DiagnosticsStore'

export type DiagnosticLogLevel = 'debug' | 'info' | 'warn' | 'error'
export type DiagnosticLogCategory = 'app' | 'auth' | 'two_factor' | 'auto_daily_checkin' | 'notification' | 'account' | 'cache' | 'storage' | 'ui_lifecycle' | 'diagnostics' | 'network' | 'webview' | 'cloud_sync'

export class DiagnosticLogger {
  private static enabled: boolean = true
  private static minLevel: DiagnosticLogLevel = 'info'
  private static mirrorToConsole: boolean = true

  static configure(enabled: boolean, minLevel: string = 'info'): void {
    try {
      DiagnosticLogger.enabled = enabled
      DiagnosticLogger.minLevel = DiagnosticLogger.normalizeLevel(minLevel)
    } catch (_error) {
      // Diagnostics must never affect app behavior.
    }
  }

  static setConsoleMirror(enabled: boolean): void {
    try {
      DiagnosticLogger.mirrorToConsole = enabled
    } catch (_error) {
    }
  }

  static initializePersistentSink(context: common.UIAbilityContext): void {
    try {
      DiagnosticsLogFileSink.initialize(context)
    } catch (_error) {
      // Diagnostics must never affect app behavior.
    }
  }

  static debug(category: DiagnosticLogCategory, event: string, context: DiagnosticContextObject = {}, error?: Error): void {
    DiagnosticLogger.log('debug', category, event, context, error)
  }

  static info(category: DiagnosticLogCategory, event: string, context: DiagnosticContextObject = {}, error?: Error): void {
    DiagnosticLogger.log('info', category, event, context, error)
  }

  static warn(category: DiagnosticLogCategory, event: string, context: DiagnosticContextObject = {}, error?: Error): void {
    DiagnosticLogger.log('warn', category, event, context, error)
  }

  static error(category: DiagnosticLogCategory, event: string, context: DiagnosticContextObject = {}, error?: Error): void {
    DiagnosticLogger.log('error', category, event, context, error)
  }

  static exception(category: DiagnosticLogCategory, event: string, error: Error, context: DiagnosticContextObject = {}): void {
    DiagnosticLogger.log('error', category, event, context, error)
  }

  static log(level: DiagnosticLogLevel, category: DiagnosticLogCategory, event: string, context: DiagnosticContextObject = {}, error?: Error): void {
    try {
      if (!DiagnosticLogger.enabled || !DiagnosticLogger.shouldLog(level)) {
        return
      }
      const entry: DiagnosticLogEntry = {
        ts: Date.now(),
        level: level,
        category: category,
        event: event,
        message: event,
        context: context || {},
        error: error ? {
          name: error.name || 'Error',
          message: error.message || ''
        } : {}
      }
      const safeEntry = DiagnosticsRedactor.sanitizeEvent(entry)
      DiagnosticsStore.append(safeEntry)
      DiagnosticsLogFileSink.append(safeEntry)
      DiagnosticLogger.consoleSink(safeEntry)
    } catch (_error) {
      // Never throw to callers.
    }
  }

  static exportText(): string {
    try {
      const latestFileText = DiagnosticsLogFileSink.exportLatestText()
      if (latestFileText.length > 0) {
        return latestFileText
      }
      return DiagnosticsStore.exportText()
    } catch (_error) {
      return ''
    }
  }

  static clear(): void {
    try {
      DiagnosticsStore.clear()
    } catch (_error) {
    }
  }

  static closePersistentSink(): void {
    try {
      DiagnosticsLogFileSink.close()
    } catch (_error) {
    }
  }

  static count(): number {
    try {
      return DiagnosticsStore.count()
    } catch (_error) {
      return 0
    }
  }

  static ownerHash(value: string): string {
    try {
      return DiagnosticsRedactor.ownerHash(value)
    } catch (_error) {
      return ''
    }
  }

  private static shouldLog(level: DiagnosticLogLevel): boolean {
    return DiagnosticLogger.levelRank(level) >= DiagnosticLogger.levelRank(DiagnosticLogger.minLevel)
  }

  private static levelRank(level: string): number {
    if (level === 'debug') {
      return 10
    }
    if (level === 'warn') {
      return 30
    }
    if (level === 'error') {
      return 40
    }
    return 20
  }

  private static normalizeLevel(level: string): DiagnosticLogLevel {
    if (level === 'debug' || level === 'info' || level === 'warn' || level === 'error') {
      return level
    }
    return 'info'
  }

  private static consoleSink(entry: DiagnosticLogEntry): void {
    try {
      if (!DiagnosticLogger.mirrorToConsole) {
        return
      }
      const text = `[next2v:diagnostics] ${entry.level} ${entry.category}.${entry.event} ${JSON.stringify(entry.context || {})}`
      if (entry.level === 'error' || entry.level === 'warn') {
        console.error(text)
      } else {
        console.info(text)
      }
    } catch (_error) {
    }
  }
}
