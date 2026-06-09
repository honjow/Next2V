import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const page = fs.readFileSync(`${root}/feature/settings/src/main/ets/pages/StorageSettingsPage.ets`, 'utf8');
const coord = fs.readFileSync(`${root}/feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets`, 'utf8');
// Export/import backup labels migrated from local R_EXPORT_BACKUP/R_IMPORT_BACKUP resource constants
// to inline $r('app.string.export_backup'|'import_backup') calls; assert the resource-backed labels.
for (const word of ['BackupFilePickerCoordinator','BackupSection','openExportSheet','confirmExportFromSheet','selectImportBackup','confirmImportBackup',"app.string.export_backup","app.string.import_backup"]) assert.ok(page.includes(word), `Storage page missing ${word}`);
// Encrypted-backup UI: include-accounts toggle, set/enter password sheets, decrypt path.
for (const word of ["app.string.backup_include_user_info",'exportIncludeUserInfo','ImportPasswordSheet','confirmDecryptImport','decryptSelected','InputType.Password']) assert.ok(page.includes(word), `Storage page missing encrypted-flow ${word}`);
// Passwords must never be persisted/logged from the page: no preferences writes, no console/Diagnostic logging of the buffers.
assert.ok(!/(console\.(log|info|warn|error)|DiagnosticLogger)[^\n]*(exportPassword|importPassword)/.test(page), 'page must not log password buffers');
for (const word of ['backupImportPreviewCopy','backupImportConfirmDialogCopy','login state','cookies','tokens','overwrite','validateExportPassword']) assert.ok(coord.includes(word), `coordinator missing ${word}`);
// AppStrings.ets is now a generic ResourceManager resolver (no per-key list); backup i18n keys are
// defined in the resource jsons and referenced as $r('app.string.<name>') in the settings source.
// Assert each key is BOTH defined (base resource json) AND used (page or coordinator) — same intent.
const baseStrings = fs.readFileSync(`${root}/entry/src/main/resources/base/element/string.json`, 'utf8');
for (const name of ['backup_section','export_backup','import_backup','backup_export_subtitle','backup_import_subtitle','backup_include_user_info','backup_set_password','backup_enter_password','backup_error_bad_password']) {
  assert.ok(baseStrings.includes(`"${name}"`), `base resource json missing ${name}`);
  assert.ok(page.includes(`app.string.${name}`) || coord.includes(`app.string.${name}`), `settings source does not reference app.string.${name}`);
}
for (const locale of ['base','en_US','zh_CN','zh_HK','zh_TW']) {
  const s = fs.readFileSync(`${root}/entry/src/main/resources/${locale}/element/string.json`, 'utf8');
  for (const name of ['backup_section','export_backup','import_backup','backup_include_user_info','backup_set_password','backup_unlock']) assert.ok(s.includes(`"${name}"`), `${locale} missing ${name}`);
}
console.log('PASS storage backup UI static');
