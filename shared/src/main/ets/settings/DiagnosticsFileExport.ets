import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { BusinessError } from '@ohos.base'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { DiagnosticContextObject } from '../diagnostics/DiagnosticsRedactor'
import { DiagnosticsSettings } from './DiagnosticsSettings'

const DIAGNOSTICS_EXPORT_DIR = 'diagnostics_exports'
const DIAGNOSTICS_EXPORT_PREFIX = 'next2v-log-export-'
const DIAGNOSTICS_EXPORT_SUFFIX = '.txt'
const DIAGNOSTICS_EXPORT_KEEP_COUNT = 3

export interface DiagnosticsExportFile {
  fileName: string
  filePath: string
  uri: string
  text: string
  directoryKind: string
}

interface DiagnosticsExportTarget {
  directory: string
  directoryKind: string
}

export class DiagnosticsFileExport {
  static create(context: common.UIAbilityContext): DiagnosticsExportFile {
    let phase = 'prepare_text'
    let fileName = ''
    let target: DiagnosticsExportTarget | null = null
    try {
      const text = DiagnosticsSettings.exportText() || '暂无诊断日志'
      fileName = DiagnosticsFileExport.safeFileName(new Date())
      phase = 'choose_directory'
      target = DiagnosticsFileExport.exportTarget(context)
      const filePath = target.directory + '/' + fileName
      phase = 'ensure_directory'
      DiagnosticsFileExport.ensureExportDirectory(target.directory)
      phase = 'write_file'
      DiagnosticsFileExport.writeTextFile(filePath, text)
      phase = 'prune_old_exports'
      DiagnosticsFileExport.pruneOldExports(context, fileName)
      return {
        fileName: fileName,
        filePath: filePath,
        uri: fileUri.getUriFromPath(filePath),
        text: text,
        directoryKind: target.directoryKind,
      }
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_file_export_error', DiagnosticsFileExport.safeErrorContext(
        phase,
        error as Error,
        target ? target.directoryKind : 'unresolved',
        fileName,
      ))
      throw new Error('Diagnostics file export failed at ' + phase)
    }
  }

  static pruneOldExports(context: common.UIAbilityContext, keepFileName: string = ''): void {
    const directory = DiagnosticsFileExport.exportTarget(context).directory
    let names: string[] = []
    try {
      names = fileIo.listFileSync(directory)
    } catch (_error) {
      return
    }
    const exportNames = names
      .filter((name: string) => DiagnosticsFileExport.isDiagnosticsExportFileName(name))
      .sort()
      .reverse()
    exportNames.forEach((name: string, index: number) => {
      if (name === keepFileName || index < DIAGNOSTICS_EXPORT_KEEP_COUNT) {
        return
      }
      try {
        fileIo.unlinkSync(directory + '/' + name)
      } catch (_error) {
      }
    })
  }

  static safeErrorContext(phase: string, error: Error, directoryKind: string = 'unknown', fileName: string = ''): DiagnosticContextObject {
    const context: DiagnosticContextObject = new Object() as DiagnosticContextObject
    context['phase'] = DiagnosticsFileExport.safeToken(phase || 'unknown')
    context['directoryKind'] = DiagnosticsFileExport.safeToken(directoryKind || 'unknown')
    if (fileName.length > 0 && DiagnosticsFileExport.isDiagnosticsExportFileName(fileName)) {
      context['fileName'] = fileName
    }
    context['errorName'] = DiagnosticsFileExport.safeShortText(DiagnosticsFileExport.errorField(error, 'name'))
    context['errorMessage'] = DiagnosticsFileExport.safeShortText(DiagnosticsFileExport.scrubFileLocations(DiagnosticsFileExport.errorField(error, 'message')))
    const code = DiagnosticsFileExport.errorField(error, 'code')
    if (code.length > 0) {
      context['errorCode'] = DiagnosticsFileExport.safeShortText(code)
    }
    return context
  }

  private static safeFileName(date: Date): string {
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    const second = date.getSeconds().toString().padStart(2, '0')
    return `${DIAGNOSTICS_EXPORT_PREFIX}${year}${month}${day}-${hour}${minute}${second}${DIAGNOSTICS_EXPORT_SUFFIX}`
  }

  private static exportTarget(context: common.UIAbilityContext): DiagnosticsExportTarget {
    const cacheDir = DiagnosticsFileExport.nonEmptyDir(context.cacheDir)
    if (cacheDir.length > 0) {
      return {
        directory: cacheDir + '/' + DIAGNOSTICS_EXPORT_DIR,
        directoryKind: 'cacheDir',
      }
    }
    const filesDir = DiagnosticsFileExport.nonEmptyDir(context.filesDir)
    if (filesDir.length > 0) {
      return {
        directory: filesDir + '/' + DIAGNOSTICS_EXPORT_DIR,
        directoryKind: 'filesDir',
      }
    }
    throw new Error('Diagnostics export directory unavailable')
  }

  private static ensureExportDirectory(directory: string): void {
    try {
      // Current @kit.CoreFileKit fileIo SDK declares mkdirSync(path, recursion: boolean).
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      try {
        fileIo.listFileSync(directory)
        return
      } catch (_listError) {
      }
      throw new Error('Diagnostics export directory create failed')
    }
  }

  private static writeTextFile(filePath: string, text: string): void {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, text)
    } finally {
      DiagnosticsFileExport.closeFileBestEffort(file)
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

  private static isDiagnosticsExportFileName(fileName: string): boolean {
    if (!fileName.startsWith(DIAGNOSTICS_EXPORT_PREFIX) || !fileName.endsWith(DIAGNOSTICS_EXPORT_SUFFIX)) {
      return false
    }
    if (fileName.includes('/') || fileName.includes('\\') || fileName.includes('..')) {
      return false
    }
    const middle = fileName.substring(
      DIAGNOSTICS_EXPORT_PREFIX.length,
      fileName.length - DIAGNOSTICS_EXPORT_SUFFIX.length,
    )
    if (middle.length !== 'YYYYMMDD-HHMMSS'.length || middle.charAt(8) !== '-') {
      return false
    }
    const digits = middle.substring(0, 8) + middle.substring(9)
    for (let i = 0; i < digits.length; i++) {
      const code = digits.charCodeAt(i)
      if (code < 48 || code > 57) {
        return false
      }
    }
    return true
  }

  private static nonEmptyDir(value: string): string {
    let clean = (value || '').trim()
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1)
    }
    return clean
  }

  private static errorField(error: Error, key: string): string {
    try {
      if (!error || !key) {
        return ''
      }
      if (key === 'name') {
        return error.name || ''
      }
      if (key === 'message') {
        return error.message || ''
      }
      if (key === 'code') {
        const businessError = error as BusinessError
        if (businessError.code !== undefined) {
          return `${businessError.code}`
        }
      }
      return ''
    } catch (_error) {
      return ''
    }
  }

  private static scrubFileLocations(value: string): string {
    const clean = value || ''
    return clean.replace(/\/[^\s:]+\/([^\/\s:]+)/g, '/<path>/$1')
  }

  private static safeShortText(value: string): string {
    const clean = value || ''
    if (clean.length > 120) {
      return clean.substring(0, 120) + '…'
    }
    return clean
  }

  private static safeToken(value: string): string {
    return (value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 80)
  }
}
