import { util } from '@kit.ArkTS'
import { BackupChecksum } from './BackupChecksum'
import type { BackupEnvelopeV1, BackupParseResult, BackupPreview, BackupSectionName, BackupValidationResult } from './BackupTypes'
import { BACKUP_APP_ID, BACKUP_MAGIC, BACKUP_SCHEMA_VERSION, BACKUP_SECTION_NAMES, MAX_BACKUP_BYTES } from './BackupTypes'

export class BackupValidator {
  static validateRawTextSize(byteLength: number): BackupValidationResult {
    if (byteLength > MAX_BACKUP_BYTES) {
      return BackupValidator.fail('too_large', 'Backup file is too large.')
    }
    return BackupValidator.pass()
  }

  static async parseEnvelope(raw: string): Promise<BackupParseResult> {
    const encoder = new util.TextEncoder()
    const size = BackupValidator.validateRawTextSize(encoder.encodeInto(raw).length)
    if (!size.ok) {
      return { ok: false, code: size.code, message: size.message }
    }
    let parsed: Object
    try {
      parsed = JSON.parse(raw) as Object
    } catch (_error) {
      return { ok: false, code: 'not_json', message: 'This file is not valid JSON.' }
    }
    if (Array.isArray(parsed) || parsed === null || typeof parsed !== 'object') {
      return { ok: false, code: 'not_json', message: 'Backup root must be a JSON object.' }
    }
    const result = await BackupValidator.validateEnvelope(parsed)
    if (!result.ok) {
      return { ok: false, code: result.code, message: result.message }
    }
    return { ok: true, envelope: parsed as BackupEnvelopeV1, code: '', message: '' }
  }

  static async validateEnvelope(value: Object): Promise<BackupValidationResult> {
    if (Array.isArray(value) || value === null || typeof value !== 'object') {
      return BackupValidator.fail('not_json', 'Backup root must be a JSON object.')
    }
    const envelope = value as BackupEnvelopeV1
    if (envelope.magic !== BACKUP_MAGIC || envelope.appId !== BACKUP_APP_ID) {
      return BackupValidator.fail('foreign_backup', 'This file is not a V2Next backup.')
    }
    if (envelope.schemaVersion !== BACKUP_SCHEMA_VERSION || envelope.minSupportedSchemaVersion > BACKUP_SCHEMA_VERSION) {
      return BackupValidator.fail('unsupported_version', 'Unsupported backup version.')
    }
    if (!Array.isArray(envelope.sections) || !envelope.data || typeof envelope.data !== 'object') {
      return BackupValidator.fail('malformed_section', 'Backup sections are malformed.')
    }
    for (let i = 0; i < envelope.sections.length; i++) {
      const section = envelope.sections[i]
      if (BACKUP_SECTION_NAMES.indexOf(section) < 0) {
        return BackupValidator.fail('malformed_section', 'Unknown backup section.')
      }
      if ((envelope.data as Record<string, Object | undefined>)[section] === undefined) {
        return BackupValidator.fail('malformed_section', 'Backup section payload is missing.')
      }
    }
    if (!envelope.counts || typeof envelope.counts !== 'object') {
      return BackupValidator.fail('malformed_section', 'Backup counts are malformed.')
    }
    const checksumOk = await BackupChecksum.verifyEnvelope(envelope)
    if (!checksumOk) {
      return BackupValidator.fail('bad_checksum', 'Backup is damaged or failed checksum validation.')
    }
    return BackupValidator.pass()
  }

  static preview(envelope: BackupEnvelopeV1): BackupPreview {
    return {
      createdAt: envelope.createdAt,
      appVersion: envelope.appVersion,
      appVersionCode: envelope.appVersionCode,
      sections: envelope.sections,
      counts: envelope.counts,
      warning: 'Login state, cookies, tokens, and cache are not included and will not be changed.'
    }
  }

  static sectionNames(): BackupSectionName[] {
    return BACKUP_SECTION_NAMES.slice()
  }

  private static pass(): BackupValidationResult {
    return { ok: true, code: '', message: '' }
  }

  private static fail(code: string, message: string): BackupValidationResult {
    return { ok: false, code: code, message: message }
  }
}
