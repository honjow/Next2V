import { util } from '@kit.ArkTS'
import { BackupChecksum } from './BackupChecksum'
import type {
  BackupEncryptedEnvelope,
  BackupEnvelopeV1,
  BackupParseResult,
  BackupPreview,
  BackupSectionName,
  BackupValidationResult,
} from './BackupTypes'
import {
  BACKUP_APP_ID,
  BACKUP_ENCRYPTED_ONLY_SECTION_NAMES,
  BACKUP_MAGIC,
  BACKUP_SCHEMA_VERSION,
  BACKUP_SECTION_NAMES,
  MAX_BACKUP_BYTES,
} from './BackupTypes'

// Sections accepted inside a decrypted envelope: the plaintext-eligible set plus the
// encryption-only set (userInfo). A plaintext file can only carry the plaintext-eligible set.
const VALID_ENVELOPE_SECTIONS: BackupSectionName[] = BACKUP_SECTION_NAMES.concat(
  BACKUP_ENCRYPTED_ONLY_SECTION_NAMES,
)

export class BackupValidator {
  static validateRawTextSize(byteLength: number): BackupValidationResult {
    if (byteLength > MAX_BACKUP_BYTES) {
      return BackupValidator.fail('too_large', 'Backup file is too large.')
    }
    return BackupValidator.pass()
  }

  static async parseEnvelope(
    raw: string,
    fromEncrypted: boolean = false,
  ): Promise<BackupParseResult> {
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
    // A sealed Next2V backup is recognizable without the password: signal the caller to prompt
    // for one rather than treating it as malformed. Only relevant on the direct (file) parse;
    // the post-decrypt parse never sees an encrypted container again.
    if (!fromEncrypted && BackupValidator.isEncryptedContainer(parsed)) {
      return {
        ok: false,
        encrypted: true,
        code: 'password_required',
        message: 'This backup is encrypted. Enter the password to import.',
      }
    }
    const result = await BackupValidator.validateEnvelope(parsed, fromEncrypted)
    if (!result.ok) {
      return { ok: false, code: result.code, message: result.message }
    }
    return { ok: true, envelope: parsed as BackupEnvelopeV1, code: '', message: '' }
  }

  static isEncryptedContainer(value: Object): boolean {
    if (Array.isArray(value) || value === null || typeof value !== 'object') {
      return false
    }
    const container = value as BackupEncryptedEnvelope
    return (
      container.magic === BACKUP_MAGIC &&
      container.appId === BACKUP_APP_ID &&
      container.encrypted === true
    )
  }

  // True when the envelope declares any encryption-only section (userInfo). Such an envelope can
  // only originate from a decrypted container, so restore must validate it with fromEncrypted=true.
  static hasEncryptedOnlySection(envelope: BackupEnvelopeV1): boolean {
    if (!envelope || !Array.isArray(envelope.sections)) {
      return false
    }
    for (let i = 0; i < envelope.sections.length; i++) {
      if (BACKUP_ENCRYPTED_ONLY_SECTION_NAMES.indexOf(envelope.sections[i]) >= 0) {
        return true
      }
    }
    return false
  }

  static async validateEnvelope(
    value: Object,
    fromEncrypted: boolean = false,
  ): Promise<BackupValidationResult> {
    if (Array.isArray(value) || value === null || typeof value !== 'object') {
      return BackupValidator.fail('not_json', 'Backup root must be a JSON object.')
    }
    const envelope = value as BackupEnvelopeV1
    if (envelope.magic !== BACKUP_MAGIC || envelope.appId !== BACKUP_APP_ID) {
      return BackupValidator.fail('foreign_backup', 'This file is not a V2Next backup.')
    }
    if (
      envelope.schemaVersion > BACKUP_SCHEMA_VERSION ||
      envelope.minSupportedSchemaVersion > BACKUP_SCHEMA_VERSION
    ) {
      return BackupValidator.fail('unsupported_version', 'Unsupported backup version.')
    }
    if (!Array.isArray(envelope.sections) || !envelope.data || typeof envelope.data !== 'object') {
      return BackupValidator.fail('malformed_section', 'Backup sections are malformed.')
    }
    for (let i = 0; i < envelope.sections.length; i++) {
      const section = envelope.sections[i]
      // Encryption-only sections (userInfo) are valid ONLY inside a decrypted envelope; if they
      // ever appear in a plaintext file we reject it so credentials can never ride in cleartext.
      const isEncryptedOnly = BACKUP_ENCRYPTED_ONLY_SECTION_NAMES.indexOf(section) >= 0
      if (isEncryptedOnly && !fromEncrypted) {
        return BackupValidator.fail('malformed_section', 'Unknown backup section.')
      }
      if (VALID_ENVELOPE_SECTIONS.indexOf(section) < 0) {
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
      return BackupValidator.fail(
        'bad_checksum',
        'Backup is damaged or failed checksum validation.',
      )
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
      warning: 'Login state, cookies, tokens, and cache are not included and will not be changed.',
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
