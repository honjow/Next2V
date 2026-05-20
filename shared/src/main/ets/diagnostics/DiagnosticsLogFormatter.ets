import { DiagnosticsRedactor, DiagnosticContextObject, DiagnosticContextValue, DiagnosticLogEntry } from './DiagnosticsRedactor'

export class DiagnosticsLogFormatter {
  static formatEntry(entry: DiagnosticLogEntry): string {
    try {
      const safeEntry = DiagnosticsRedactor.sanitizeEvent(entry)
      const pieces: string[] = []
      pieces.push(DiagnosticsLogFormatter.formatTimestamp(safeEntry.ts))
      pieces.push('[' + DiagnosticsLogFormatter.levelLabel(safeEntry.level) + ']')
      pieces.push(DiagnosticsLogFormatter.safeName(safeEntry.category) + '.' + DiagnosticsLogFormatter.safeName(safeEntry.event))
      const message = DiagnosticsLogFormatter.cleanText(safeEntry.message || safeEntry.event || '')
      if (message.length > 0) {
        pieces.push(message)
      }
      const contextText = DiagnosticsLogFormatter.formatObject(safeEntry.context || (new Object() as DiagnosticContextObject))
      if (contextText.length > 0) {
        pieces.push(contextText)
      }
      const errorText = DiagnosticsLogFormatter.formatError(safeEntry.error || (new Object() as DiagnosticContextObject))
      if (errorText.length > 0) {
        pieces.push(errorText)
      }
      return pieces.join(' ')
    } catch (_error) {
      return DiagnosticsLogFormatter.formatTimestamp(Date.now()) + ' [ERROR] diagnostics.format_error Diagnostic log format failed'
    }
  }

  static formatEntries(entries: DiagnosticLogEntry[]): string {
    try {
      return (entries || [])
        .map((entry: DiagnosticLogEntry) => DiagnosticsLogFormatter.formatEntry(entry))
        .join('\n')
    } catch (_error) {
      return ''
    }
  }

  static formatJsonlEntries(entries: DiagnosticLogEntry[]): string {
    try {
      return (entries || [])
        .map((entry: DiagnosticLogEntry) => JSON.stringify(DiagnosticsRedactor.sanitizeEvent(entry)))
        .join('\n')
    } catch (_error) {
      return ''
    }
  }

  private static formatObject(context: DiagnosticContextObject): string {
    try {
      const keys = Object.keys(context || (new Object() as DiagnosticContextObject))
      return keys
        .map((key: string) => {
          return DiagnosticsLogFormatter.safeName(key) + '=' + DiagnosticsLogFormatter.formatValue(context[key] as DiagnosticContextValue)
        })
        .join(' ')
    } catch (_error) {
      return ''
    }
  }

  private static formatError(error: DiagnosticContextObject): string {
    try {
      const keys = Object.keys(error || (new Object() as DiagnosticContextObject))
      if (keys.length <= 0) {
        return ''
      }
      return keys
        .map((key: string) => {
          return 'error.' + DiagnosticsLogFormatter.safeName(key) + '=' + DiagnosticsLogFormatter.formatValue(error[key] as DiagnosticContextValue)
        })
        .join(' ')
    } catch (_error) {
      return ''
    }
  }

  private static formatValue(value: DiagnosticContextValue): string {
    if (value === null || value === undefined) {
      return '<omitted>'
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return `${value}`
    }
    if (typeof value === 'string') {
      return DiagnosticsLogFormatter.quoteIfNeeded(DiagnosticsLogFormatter.cleanText(value))
    }
    try {
      return DiagnosticsLogFormatter.quoteIfNeeded(DiagnosticsLogFormatter.cleanText(JSON.stringify(value)))
    } catch (_error) {
      return '<omitted>'
    }
  }

  private static quoteIfNeeded(value: string): string {
    const clean = value || ''
    if (clean.length <= 0) {
      return '""'
    }
    if (/\s/.test(clean) || clean.indexOf('=') >= 0) {
      return '"' + clean.replace(/"/g, '\\"') + '"'
    }
    return clean
  }

  private static cleanText(value: string): string {
    return (value || '')
      .replace(/\r/g, ' ')
      .replace(/\n/g, ' ')
      .replace(/\t/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static levelLabel(level: string): string {
    const clean = (level || 'info').toUpperCase()
    if (clean === 'DEBUG' || clean === 'INFO' || clean === 'WARN' || clean === 'ERROR') {
      return clean
    }
    return 'INFO'
  }

  private static safeName(value: string): string {
    const clean = (value || 'unknown').replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 80)
    return clean.length > 0 ? clean : 'unknown'
  }

  private static formatTimestamp(ts: number): string {
    const date = new Date(ts > 0 ? ts : Date.now())
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    const second = date.getSeconds().toString().padStart(2, '0')
    const millis = date.getMilliseconds().toString().padStart(3, '0')
    return `${year}-${month}-${day} ${hour}:${minute}:${second}.${millis}`
  }
}
