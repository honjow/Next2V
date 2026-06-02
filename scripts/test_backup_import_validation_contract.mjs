import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const validator = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupValidator.ets`, 'utf8');
const service = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupService.ets`, 'utf8');
for (const code of ['not_json','foreign_backup','unsupported_version','bad_checksum','too_large','malformed_section']) assert.ok(validator.includes(code), `missing error code ${code}`);
// schemaVersion guard is now ">" (forward-only) so plaintext v1 files still import into v2 builds,
// while a future v3 file is rejected. minSupported is still enforced as an upper bound.
for (const guard of ['Array.isArray(parsed)','magic !== BACKUP_MAGIC','appId !== BACKUP_APP_ID','schemaVersion > BACKUP_SCHEMA_VERSION','minSupportedSchemaVersion > BACKUP_SCHEMA_VERSION','validateRawTextSize','BackupChecksum.verifyEnvelope']) assert.ok(validator.includes(guard), `missing validation guard ${guard}`);
assert.ok(validator.includes('unknown section') || validator.includes('Unknown backup section'), 'unknown sections are rejected');
// Encrypted-backup detection + wrong-password handling.
assert.ok(validator.includes('password_required'), 'encrypted backups surface a password_required code');
assert.ok(validator.includes('isEncryptedContainer'), 'validator detects the encrypted container');
assert.ok(service.includes('bad_password'), 'wrong password / tampered cipher surfaces bad_password');
assert.ok(service.includes('decryptAndPreview'), 'service exposes the decrypt+preview path');
// Encryption-only sections (userInfo) must be rejected when seen in a plaintext (non-decrypted) file.
assert.ok(validator.includes('BACKUP_ENCRYPTED_ONLY_SECTION_NAMES') && validator.includes('fromEncrypted'), 'plaintext envelopes reject encryption-only sections');
console.log('PASS backup import validation contract');
