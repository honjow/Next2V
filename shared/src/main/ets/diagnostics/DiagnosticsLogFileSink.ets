import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { DiagnosticsRedactor, DiagnosticContextObject, DiagnosticLogEntry } from './DiagnosticsRedactor'
import { DiagnosticsLogFormatter } from './DiagnosticsLogFormatter'

export const DIAGNOSTICS_LOG_DIR: string = 'diagnostics_logs'
export const DIAGNOSTICS_LOG_PREFIX: string = 'next2v-log-'
export const DIAGNOSTICS_LOG_SUFFIX: string = '.txt'
export const DIAGNOSTICS_LOG_KEEP_COUNT: number = 10
export const DIAGNOSTICS_LOG_MAX_AGE_DAYS: number = 14
export const DIAGNOSTICS_LOG_MAX_TOTAL_BYTES: number = 5 * 1024 * 1024
export const TWO_FACTOR_LOG_PREFIX: string = 'next2v-2fa-'
export const TWO_FACTOR_LOG_KEEP_COUNT: number = 20
export const TWO_FACTOR_LOG_MAX_AGE_DAYS: number = 30
export const TWO_FACTOR_LOG_MAX_TOTAL_BYTES: number = 2 * 1024 * 1024
const TWO_FACTOR_LOG_MAX_FILE_BYTES: number = 256 * 1024

export interface DiagnosticsLogFileInfo {
  fileName: string
  filePath: string
  directory: string
  uri: string
  sizeBytes: number
  createdAtMs: number
  isCurrent: boolean
}

export class DiagnosticsLogFileSink {
  private static directory: string = ''
  private static currentFileName: string = ''
  private static currentFilePath: string = ''
  private static disabled: boolean = false
  private static initialized: boolean = false
  private static incidentFlowId: string = ''
  private static incidentFileName: string = ''
  private static incidentBytes: number = 0

  static initialize(context: common.UIAbilityContext): void {
    try {
      const filesDir = DiagnosticsLogFileSink.nonEmptyDir(context.filesDir)
      if (filesDir.length <= 0) {
        DiagnosticsLogFileSink.disableMemoryOnly()
        return
      }
      DiagnosticsLogFileSink.directory = filesDir + '/' + DIAGNOSTICS_LOG_DIR
      DiagnosticsLogFileSink.ensureDirectory(DiagnosticsLogFileSink.directory)
      DiagnosticsLogFileSink.currentFileName = DiagnosticsLogFileSink.createUniqueFileName(DiagnosticsLogFileSink.directory, new Date())
      DiagnosticsLogFileSink.currentFilePath = DiagnosticsLogFileSink.directory + '/' + DiagnosticsLogFileSink.currentFileName
      DiagnosticsLogFileSink.writeTextFile(DiagnosticsLogFileSink.currentFilePath, '', true)
      DiagnosticsLogFileSink.initialized = true
      DiagnosticsLogFileSink.disabled = false
      DiagnosticsLogFileSink.incidentFlowId = ''
      DiagnosticsLogFileSink.incidentFileName = ''
      DiagnosticsLogFileSink.incidentBytes = 0
      DiagnosticsLogFileSink.pruneRetainedLogs()
    } catch (error) {
      DiagnosticsLogFileSink.disableMemoryOnly()
      DiagnosticsLogFileSink.consoleFailure('initialize', error as Error)
    }
  }

  static append(entry: DiagnosticLogEntry): void {
    try {
      if (DiagnosticsLogFileSink.disabled || !DiagnosticsLogFileSink.initialized || DiagnosticsLogFileSink.currentFilePath.length <= 0) {
        return
      }
      const safeEntry = DiagnosticsRedactor.sanitizeEvent(entry)
      // Keep a separate, bounded journal so normal traffic/restarts cannot evict
      // the authentication incident before the user can export it after re-login.
      if (safeEntry.category === 'two_factor') {
        DiagnosticsLogFileSink.appendIncident(safeEntry)
      }
      DiagnosticsLogFileSink.writeTextFile(
        DiagnosticsLogFileSink.currentFilePath,
        DiagnosticsLogFormatter.formatEntry(safeEntry) + '\n',
        false,
      )
    } catch (error) {
      DiagnosticsLogFileSink.disabled = true
      DiagnosticsLogFileSink.consoleFailure('append', error as Error)
    }
  }

  static exportLatestText(): string {
    try {
      const path = DiagnosticsLogFileSink.latestLogPath()
      if (path.length <= 0) {
        return ''
      }
      return fileIo.readTextSync(path)
    } catch (_error) {
      return ''
    }
  }

  static currentInfo(): DiagnosticsLogFileInfo | null {
    try {
      if (!DiagnosticsLogFileSink.initialized || DiagnosticsLogFileSink.currentFileName.length <= 0) {
        return null
      }
      return {
        fileName: DiagnosticsLogFileSink.currentFileName,
        filePath: DiagnosticsLogFileSink.currentFilePath,
        directory: DiagnosticsLogFileSink.directory,
        uri: fileUri.getUriFromPath(DiagnosticsLogFileSink.currentFilePath),
        sizeBytes: DiagnosticsLogFileSink.approxFileBytes(DiagnosticsLogFileSink.currentFilePath),
        createdAtMs: DiagnosticsLogFileSink.createdAtMsFromFileName(DiagnosticsLogFileSink.currentFileName),
        isCurrent: true,
      }
    } catch (_error) {
      return null
    }
  }

  static listRetainedLogFiles(): DiagnosticsLogFileInfo[] {
    try {
      if (DiagnosticsLogFileSink.directory.length <= 0) {
        return []
      }
      return DiagnosticsLogFileSink.listSafeLogNames().sort().reverse().map((name: string): DiagnosticsLogFileInfo => {
        const path = DiagnosticsLogFileSink.directory + '/' + name
        return {
          fileName: name,
          filePath: path,
          directory: DiagnosticsLogFileSink.directory,
          uri: fileUri.getUriFromPath(path),
          sizeBytes: DiagnosticsLogFileSink.approxFileBytes(path),
          createdAtMs: DiagnosticsLogFileSink.createdAtMsFromFileName(name),
          isCurrent: name === DiagnosticsLogFileSink.currentFileName,
        }
      })
    } catch (_error) {
      return []
    }
  }

  static readLogFileText(fileName: string): string {
    try {
      if (DiagnosticsLogFileSink.directory.length <= 0 || !DiagnosticsLogFileSink.isDiagnosticsLogFileName(fileName)) {
        return ''
      }
      return fileIo.readTextSync(DiagnosticsLogFileSink.directory + '/' + fileName)
    } catch (_error) {
      return ''
    }
  }

  static close(): void {
    try {
      // Writes are append-only and close their file handle per entry. Kept for lifecycle symmetry.
      DiagnosticsLogFileSink.pruneRetainedLogs()
    } catch (_error) {
    }
  }

  static safeErrorContext(phase: string, error: Error): DiagnosticContextObject {
    const context: DiagnosticContextObject = new Object() as DiagnosticContextObject
    context['phase'] = DiagnosticsLogFileSink.safeToken(phase || 'unknown')
    context['errorName'] = DiagnosticsLogFileSink.safeShortText(error && error.name ? error.name : 'Error')
    context['errorMessage'] = DiagnosticsLogFileSink.safeShortText(
      DiagnosticsLogFileSink.scrubFileLocations(error && error.message ? error.message : '')
    )
    return context
  }

  static isDiagnosticsLogFileName(fileName: string): boolean {
    const prefix = fileName.startsWith(TWO_FACTOR_LOG_PREFIX) ? TWO_FACTOR_LOG_PREFIX : DIAGNOSTICS_LOG_PREFIX
    if (!fileName.startsWith(prefix) || !fileName.endsWith(DIAGNOSTICS_LOG_SUFFIX)) {
      return false
    }
    if (fileName.includes('/') || fileName.includes('\\') || fileName.includes('..')) {
      return false
    }
    const middle = fileName.substring(prefix.length, fileName.length - DIAGNOSTICS_LOG_SUFFIX.length)
    const baseLength = 'YYYYMMDD-HHMMSS'.length
    if (middle.length !== baseLength && (middle.length <= baseLength + 1 || middle.charAt(baseLength) !== '-')) {
      return false
    }
    if (middle.charAt(8) !== '-') {
      return false
    }
    const timestampDigits = middle.substring(0, 8) + middle.substring(9, 15)
    if (!DiagnosticsLogFileSink.allDigits(timestampDigits)) {
      return false
    }
    if (middle.length > baseLength) {
      const suffix = middle.substring(baseLength + 1)
      if (suffix.length <= 0 || !DiagnosticsLogFileSink.allDigits(suffix)) {
        return false
      }
    }
    return true
  }

  private static latestLogPath(): string {
    if (DiagnosticsLogFileSink.currentFilePath.length > 0 && DiagnosticsLogFileSink.fileExists(DiagnosticsLogFileSink.currentFilePath)) {
      return DiagnosticsLogFileSink.currentFilePath
    }
    if (DiagnosticsLogFileSink.directory.length <= 0) {
      return ''
    }
    const names = DiagnosticsLogFileSink.listSafeLogNames().sort().reverse()
    if (names.length <= 0) {
      return ''
    }
    return DiagnosticsLogFileSink.directory + '/' + names[0]
  }

  private static pruneRetainedLogs(): void {
    if (DiagnosticsLogFileSink.directory.length <= 0) {
      return
    }
    DiagnosticsLogFileSink.pruneGroup(DIAGNOSTICS_LOG_PREFIX, DIAGNOSTICS_LOG_KEEP_COUNT,
      DIAGNOSTICS_LOG_MAX_AGE_DAYS, DIAGNOSTICS_LOG_MAX_TOTAL_BYTES)
    DiagnosticsLogFileSink.pruneGroup(TWO_FACTOR_LOG_PREFIX, TWO_FACTOR_LOG_KEEP_COUNT,
      TWO_FACTOR_LOG_MAX_AGE_DAYS, TWO_FACTOR_LOG_MAX_TOTAL_BYTES - TWO_FACTOR_LOG_MAX_FILE_BYTES)
  }

  private static pruneGroup(prefix: string, keepCount: number, maxAgeDays: number, maxBytes: number): void {
    const names = DiagnosticsLogFileSink.listSafeLogNames().filter((name: string) => name.startsWith(prefix)).sort().reverse()
    const now = Date.now()
    let totalBytes = 0
    names.forEach((name: string, index: number) => {
      const path = DiagnosticsLogFileSink.directory + '/' + name
      const protectedCurrent = name === DiagnosticsLogFileSink.currentFileName || name === DiagnosticsLogFileSink.incidentFileName
      const ageExpired = DiagnosticsLogFileSink.fileAgeMs(name, now) > maxAgeDays * 24 * 60 * 60 * 1000
      const size = DiagnosticsLogFileSink.approxFileBytes(path)
      totalBytes += size
      if (protectedCurrent) {
        return
      }
      if (index >= keepCount || ageExpired || totalBytes > maxBytes) {
        DiagnosticsLogFileSink.unlinkBestEffort(path)
      }
    })
  }

  private static appendIncident(entry: DiagnosticLogEntry): void {
    try {
      const flowId = entry.context?.flowId as string || 'unassigned'
      const line = DiagnosticsLogFormatter.formatEntry(entry) + '\n'
      const bytes = DiagnosticsLogFileSink.byteLength(line)
      if (DiagnosticsLogFileSink.incidentFlowId !== flowId || !DiagnosticsLogFileSink.incidentFileName ||
        DiagnosticsLogFileSink.incidentBytes + bytes > TWO_FACTOR_LOG_MAX_FILE_BYTES) {
        DiagnosticsLogFileSink.incidentFlowId = flowId
        DiagnosticsLogFileSink.incidentFileName = DiagnosticsLogFileSink.createUniqueFileName(
          DiagnosticsLogFileSink.directory, new Date(), TWO_FACTOR_LOG_PREFIX)
        DiagnosticsLogFileSink.incidentBytes = 0
        DiagnosticsLogFileSink.writeTextFile(DiagnosticsLogFileSink.directory + '/' + DiagnosticsLogFileSink.incidentFileName, '', true)
        DiagnosticsLogFileSink.pruneRetainedLogs()
      }
      DiagnosticsLogFileSink.writeTextFile(DiagnosticsLogFileSink.directory + '/' + DiagnosticsLogFileSink.incidentFileName, line, false)
      DiagnosticsLogFileSink.incidentBytes += bytes
    } catch (error) {
      DiagnosticsLogFileSink.consoleFailure('two_factor_journal', error as Error)
    }
  }

  private static listSafeLogNames(): string[] {
    try {
      return fileIo.listFileSync(DiagnosticsLogFileSink.directory)
        .filter((name: string) => DiagnosticsLogFileSink.isDiagnosticsLogFileName(name))
    } catch (_error) {
      return []
    }
  }

  private static createUniqueFileName(directory: string, date: Date, prefix: string = DIAGNOSTICS_LOG_PREFIX): string {
    const stem = DiagnosticsLogFileSink.timestampStem(date)
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const suffix = attempt === 0 ? '' : '-' + attempt.toString().padStart(2, '0')
      const candidate = prefix + stem + suffix + DIAGNOSTICS_LOG_SUFFIX
      if (!DiagnosticsLogFileSink.fileExists(directory + '/' + candidate)) {
        return candidate
      }
    }
    return prefix + stem + '-' + Date.now().toString() + DIAGNOSTICS_LOG_SUFFIX
  }

  private static timestampStem(date: Date): string {
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    const second = date.getSeconds().toString().padStart(2, '0')
    return `${year}${month}${day}-${hour}${minute}${second}`
  }

  private static fileAgeMs(fileName: string, now: number): number {
    const createdAtMs = DiagnosticsLogFileSink.createdAtMsFromFileName(fileName)
    if (createdAtMs <= 0) {
      return 0
    }
    return Math.max(0, now - createdAtMs)
  }

  private static createdAtMsFromFileName(fileName: string): number {
    try {
      const prefix = fileName.startsWith(TWO_FACTOR_LOG_PREFIX) ? TWO_FACTOR_LOG_PREFIX : DIAGNOSTICS_LOG_PREFIX
      const middle = fileName.substring(prefix.length, prefix.length + 'YYYYMMDD-HHMMSS'.length)
      const year = Number(middle.substring(0, 4))
      const month = Number(middle.substring(4, 6)) - 1
      const day = Number(middle.substring(6, 8))
      const hour = Number(middle.substring(9, 11))
      const minute = Number(middle.substring(11, 13))
      const second = Number(middle.substring(13, 15))
      return new Date(year, month, day, hour, minute, second).getTime()
    } catch (_error) {
      return 0
    }
  }

  private static approxFileBytes(path: string): number {
    try {
      const text = fileIo.readTextSync(path)
      return DiagnosticsLogFileSink.byteLength(text)
    } catch (_error) {
      return 0
    }
  }

  private static byteLength(value: string): number {
    let bytes = 0
    for (let i = 0; i < value.length; i += 1) {
      const code = value.charCodeAt(i)
      if (code <= 0x7F) {
        bytes += 1
      } else if (code <= 0x7FF) {
        bytes += 2
      } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
        bytes += 4
        i += 1
      } else {
        bytes += 3
      }
    }
    return bytes
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (_error) {
      fileIo.listFileSync(directory)
    }
  }

  private static writeTextFile(path: string, text: string, truncate: boolean): void {
    let file: fileIo.File | null = null
    try {
      const mode = truncate ?
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC :
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND
      file = fileIo.openSync(path, mode)
      fileIo.writeSync(file.fd, text)
    } finally {
      DiagnosticsLogFileSink.closeFileBestEffort(file)
    }
  }

  private static closeFileBestEffort(file: fileIo.File | null): void {
    if (!file) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (_error) {
    }
  }

  private static fileExists(path: string): boolean {
    try {
      return fileIo.accessSync(path)
    } catch (_error) {
      return false
    }
  }

  private static unlinkBestEffort(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {
    }
  }

  private static disableMemoryOnly(): void {
    DiagnosticsLogFileSink.disabled = true
    DiagnosticsLogFileSink.initialized = false
    DiagnosticsLogFileSink.currentFileName = ''
    DiagnosticsLogFileSink.currentFilePath = ''
  }

  private static consoleFailure(phase: string, error: Error): void {
    try {
      console.error('[next2v:diagnostics] persistent log sink disabled phase=' + DiagnosticsLogFileSink.safeToken(phase) + ' error=' + DiagnosticsLogFileSink.safeConsoleFailureMessage(error))
    } catch (_error) {
    }
  }

  private static safeConsoleFailureMessage(error: Error): string {
    const message = error && error.message ? error.message : 'unknown'
    return DiagnosticsLogFileSink.safeShortText(
      DiagnosticsLogFileSink.scrubSensitiveConsoleText(
        DiagnosticsLogFileSink.scrubFileLocations(message)
      )
    )
  }

  private static nonEmptyDir(value: string): string {
    let clean = (value || '').trim()
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1)
    }
    return clean
  }

  private static allDigits(value: string): boolean {
    if (value.length <= 0) {
      return false
    }
    for (let i = 0; i < value.length; i += 1) {
      const code = value.charCodeAt(i)
      if (code < 48 || code > 57) {
        return false
      }
    }
    return true
  }

  private static safeToken(value: string): string {
    return (value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 80)
  }

  private static scrubFileLocations(value: string): string {
    const clean = value || ''
    return clean.replace(/\/[^\s:]+\/([^\/\s:]+)/g, '/<path>/$1')
  }

  private static scrubSensitiveConsoleText(value: string): string {
    let clean = value || ''
    clean = clean.replace(/(Cookie|Set-Cookie)\s*[:=][^;\n\s]+/gi, '$1=<redacted>')
    clean = clean.replace(/Authorization\s*[:=]\s*(Bearer\s+)?[^\s;]+/gi, 'Authorization=<redacted>')
    clean = clean.replace(/Bearer\s+[A-Za-z0-9._~+\/-]+/gi, 'Bearer <redacted>')
    clean = clean.replace(/\b(https?|socks5):\/\/[^\s/@]+:[^\s/@]*@/gi, '$1://<redacted>@')
    clean = clean.replace(/([?&](once|token|auth|code|password|delete_once|redeem)[^=]*=)[^&#\s]+/gi, '$1<redacted>')
    clean = clean.replace(/\/mission\/daily\/redeem\?[^\s]+/gi, '/mission/daily/redeem?once=<redacted>')
    clean = clean.replace(/\/delete\/notification\/\d+\?[^\s]+/gi, '/delete/notification/<id>?once=<redacted>')
    clean = clean.replace(/\/thank\/(reply|topic)\/\d+\?[^\s]+/gi, '/thank/$1/<id>?once=<redacted>')
    clean = clean.replace(/\/favorite\/(topic|node)\/[^\s?]+\?[^\s]+/gi, '/favorite/$1/<id>?once=<redacted>')
    return clean
  }

  private static safeShortText(value: string): string {
    const clean = value || ''
    if (clean.length > 120) {
      return clean.substring(0, 120) + '…'
    }
    return clean
  }
}
