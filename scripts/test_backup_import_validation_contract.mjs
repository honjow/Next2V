import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const validator = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupValidator.ets`, 'utf8');
for (const code of ['not_json','foreign_backup','unsupported_version','bad_checksum','too_large','malformed_section']) assert.ok(validator.includes(code), `missing error code ${code}`);
for (const guard of ['Array.isArray(parsed)','magic !== BACKUP_MAGIC','appId !== BACKUP_APP_ID','schemaVersion !== BACKUP_SCHEMA_VERSION','validateRawTextSize','BackupChecksum.verifyEnvelope']) assert.ok(validator.includes(guard), `missing validation guard ${guard}`);
assert.ok(validator.includes('unknown section') || validator.includes('Unknown backup section'), 'unknown sections are rejected');
console.log('PASS backup import validation contract');
