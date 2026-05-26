import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const picker = fs.readFileSync(`${root}/feature/settings/src/main/ets/model/BackupFilePickerCoordinator.ets`, 'utf8');
const moduleJson = fs.readFileSync(`${root}/entry/src/main/module.json5`, 'utf8');
for (const word of ['DocumentViewPicker','DocumentSaveOptions','DocumentSelectOptions','.next2v-backup.json','fileIo.open','finally','fileIo.closeSync']) assert.ok(picker.includes(word), `picker missing ${word}`);
for (const perm of ['READ_MEDIA','WRITE_MEDIA','READ_DOCUMENT','WRITE_DOCUMENT','ohos.permission.MEDIA_LOCATION']) assert.ok(!moduleJson.includes(perm), `broad storage/media permission added: ${perm}`);
console.log('PASS backup file picker static');
