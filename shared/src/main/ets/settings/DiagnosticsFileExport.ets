import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { DiagnosticsSettings } from './DiagnosticsSettings'

const DIAGNOSTICS_EXPORT_DIR = 'diagnostics_exports'
const DIAGNOSTICS_EXPORT_PREFIX = 'next2v-diagnostics-'
const DIAGNOSTICS_EXPORT_SUFFIX = '.txt'
const DIAGNOSTICS_EXPORT_KEEP_COUNT = 3

export interface DiagnosticsExportFile {
  fileName: string
  filePath: string
  uri: string
  text: string
}

export class DiagnosticsFileExport {
  static create(context: common.UIAbilityContext): DiagnosticsExportFile {
    const text = DiagnosticsSettings.exportText() || '暂无诊断日志'
    const fileName = DiagnosticsFileExport.safeFileName(new Date())
    const directory = DiagnosticsFileExport.exportDirectory(context)
    const filePath = directory + '/' + fileName
    DiagnosticsFileExport.ensureExportDirectory(directory)
    DiagnosticsFileExport.writeTextFile(filePath, text)
    DiagnosticsFileExport.pruneOldExports(context, fileName)
    return {
      fileName: fileName,
      filePath: filePath,
      uri: fileUri.getUriFromPath(filePath),
      text: text,
    }
  }

  static pruneOldExports(context: common.UIAbilityContext, keepFileName: string = ''): void {
    const directory = DiagnosticsFileExport.exportDirectory(context)
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

  private static safeFileName(date: Date): string {
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    const second = date.getSeconds().toString().padStart(2, '0')
    return `${DIAGNOSTICS_EXPORT_PREFIX}${year}${month}${day}-${hour}${minute}${second}${DIAGNOSTICS_EXPORT_SUFFIX}`
  }

  private static exportDirectory(context: common.UIAbilityContext): string {
    return context.cacheDir + '/' + DIAGNOSTICS_EXPORT_DIR
  }

  private static ensureExportDirectory(directory: string): void {
    fileIo.mkdirSync(directory, true)
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
}
