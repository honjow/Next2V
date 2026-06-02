import { common } from '@kit.AbilityKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import {
  BackupService,
  type BackupAppMetadata,
  type BackupEnvelopeV1,
  type BackupExportOptions,
  type BackupParseResult,
  BACKUP_FILE_SUFFIX,
  MAX_BACKUP_BYTES,
} from 'shared'

export interface BackupImportSelection {
  raw: string
  parseResult: BackupParseResult
}

export class BackupFilePickerCoordinator {
  static async exportBackup(
    context: common.UIAbilityContext,
    metadata: BackupAppMetadata,
    exportOptions?: BackupExportOptions,
  ): Promise<string> {
    const raw = await BackupService.serializeBackup(context, metadata, exportOptions)
    const pickerInstance = new picker.DocumentViewPicker(context)
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [BackupFilePickerCoordinator.defaultFilename()]
    const uris = await pickerInstance.save(options)
    if (!uris || uris.length === 0) {
      throw new Error('Save cancelled')
    }
    BackupFilePickerCoordinator.writeText(uris[0], raw)
    return uris[0]
  }

  static async selectImport(context: common.UIAbilityContext): Promise<BackupImportSelection> {
    const pickerInstance = new picker.DocumentViewPicker(context)
    const options = new picker.DocumentSelectOptions()
    options.fileSuffixFilters = ['V2Next backup|.json,.next2v-backup.json']
    options.maxSelectNumber = 1
    const uris = await pickerInstance.select(options)
    if (!uris || uris.length === 0) {
      throw new Error('Open cancelled')
    }
    const raw = BackupFilePickerCoordinator.readText(uris[0])
    if (raw.length > MAX_BACKUP_BYTES) {
      throw new Error('Backup file is too large.')
    }
    return { raw: raw, parseResult: await BackupService.parseAndPreview(raw) }
  }

  // Decrypt a previously-selected encrypted backup with the user's password. The raw bytes were
  // already read by selectImport(); the password is passed straight through and never retained.
  static async decryptSelected(raw: string, password: string): Promise<BackupParseResult> {
    return await BackupService.decryptAndPreview(raw, password)
  }

  static async restoreSelected(
    context: common.UIAbilityContext,
    envelope: BackupEnvelopeV1,
  ): Promise<void> {
    const result = await BackupService.restoreBackup(context, envelope)
    if (!result.ok) {
      throw new Error(result.message)
    }
  }

  private static defaultFilename(): string {
    const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '')
    return `V2Next-backup-${stamp}${BACKUP_FILE_SUFFIX}`
  }

  private static writeText(uri: string, raw: string): void {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        uri,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      fileIo.writeSync(file.fd, raw)
    } finally {
      if (file) {
        fileIo.closeSync(file)
      }
    }
  }

  // The picker returns a file:// uri, not a sandbox path: readTextSync(path) fails on it with
  // "No such file or directory" (which surfaced as import doing nothing — never reaching the
  // encrypted-detection/password prompt). Open the uri to a fd and read bytes via readSync (the
  // mirror of writeText's writeSync(fd)), then decode like the rest of the codebase.
  private static readText(uri: string): string {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const size = fileIo.statSync(file.fd).size
      const buffer = new ArrayBuffer(size)
      const bytesRead = fileIo.readSync(file.fd, buffer)
      const decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeToString(new Uint8Array(buffer, 0, bytesRead))
    } finally {
      if (file) {
        fileIo.closeSync(file)
      }
    }
  }
}
