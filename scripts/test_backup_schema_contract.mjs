import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const types = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupTypes.ets`, 'utf8');
const validator = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupValidator.ets`, 'utf8');
const index = fs.readFileSync(`${root}/shared/src/main/ets/Index.ets`, 'utf8');
assert.match(types, /BACKUP_MAGIC:\s*string\s*=\s*'NEXT2V_BACKUP'/);
assert.match(types, /BACKUP_APP_ID:\s*string\s*=\s*'com\.honjow\.next2v'/);
// Schema bumped to v2 for the optional, encryption-only userInfo section. minSupported stays 1
// so plaintext v1 backups keep importing into newer builds.
assert.match(types, /BACKUP_SCHEMA_VERSION:\s*number\s*=\s*2/);
assert.match(types, /BACKUP_MIN_SUPPORTED_SCHEMA_VERSION:\s*number\s*=\s*1/);
for (const section of ['preferences','drafts','collections','search','notifications','userInfo']) assert.ok(types.includes(`'${section}'`), `missing section ${section}`);
// userInfo must NOT be in the plaintext-eligible BACKUP_SECTION_NAMES list (encryption-only).
assert.ok(/BACKUP_SECTION_NAMES:\s*BackupSectionName\[\]\s*=\s*\[[^\]]*?'notifications'[^\]]*?\]/s.test(types), 'BACKUP_SECTION_NAMES present');
assert.ok(types.includes('BACKUP_ENCRYPTED_ONLY_SECTION_NAMES'), 'encryption-only section list present');
for (const word of ['magic','appId','schemaVersion','sections','checksum','MAX_BACKUP_BYTES','too_large']) assert.ok(validator.includes(word), `validator missing ${word}`);
assert.ok(index.includes("./backup/BackupService"), 'Index exports BackupService');
assert.ok(index.includes("./backup/BackupValidator"), 'Index exports BackupValidator');
console.log('PASS backup schema contract');
