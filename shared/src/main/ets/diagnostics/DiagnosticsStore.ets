import { DiagnosticsRedactor, DiagnosticLogEntry } from './DiagnosticsRedactor'

const DEFAULT_MAX_ENTRIES: number = 400

export class DiagnosticsStore {
  private static entries: DiagnosticLogEntry[] = []
  private static maxEntries: number = DEFAULT_MAX_ENTRIES

  static append(entry: DiagnosticLogEntry): void {
    try {
      const safeEntry = DiagnosticsRedactor.sanitizeEvent(entry)
      DiagnosticsStore.entries.push(safeEntry)
      if (DiagnosticsStore.entries.length > DiagnosticsStore.maxEntries) {
        DiagnosticsStore.entries = DiagnosticsStore.entries.slice(DiagnosticsStore.entries.length - DiagnosticsStore.maxEntries)
      }
    } catch (_error) {
      // Diagnostics must never affect app behavior.
    }
  }

  static snapshot(): DiagnosticLogEntry[] {
    try {
      return DiagnosticsStore.entries.slice()
    } catch (_error) {
      return []
    }
  }

  static clear(): void {
    try {
      DiagnosticsStore.entries = []
    } catch (_error) {
      // ignored
    }
  }

  static exportText(): string {
    try {
      return DiagnosticsStore.snapshot()
        .map((entry: DiagnosticLogEntry) => JSON.stringify(DiagnosticsRedactor.sanitizeEvent(entry)))
        .join('\n')
    } catch (_error) {
      return ''
    }
  }

  static setMaxEntries(maxEntries: number): void {
    try {
      DiagnosticsStore.maxEntries = Math.max(50, Math.min(2000, Math.floor(maxEntries)))
      if (DiagnosticsStore.entries.length > DiagnosticsStore.maxEntries) {
        DiagnosticsStore.entries = DiagnosticsStore.entries.slice(DiagnosticsStore.entries.length - DiagnosticsStore.maxEntries)
      }
    } catch (_error) {
      DiagnosticsStore.maxEntries = DEFAULT_MAX_ENTRIES
    }
  }

  static count(): number {
    try {
      return DiagnosticsStore.entries.length
    } catch (_error) {
      return 0
    }
  }
}
