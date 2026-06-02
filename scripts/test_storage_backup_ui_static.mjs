import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const page = fs.readFileSync(`${root}/feature/settings/src/main/ets/pages/StorageSettingsPage.ets`, 'utf8');
const coord = fs.readFileSync(`${root}/feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets`, 'utf8');
const appStrings = fs.readFileSync(`${root}/shared/src/main/ets/i18n/AppStrings.ets`, 'utf8');
for (const word of ['BackupFilePickerCoordinator','BackupSection','openExportSheet','confirmExportFromSheet','selectImportBackup','confirmImportBackup','R_EXPORT_BACKUP','R_IMPORT_BACKUP']) assert.ok(page.includes(word), `Storage page missing ${word}`);
// Encrypted-backup UI: include-accounts toggle, set/enter password sheets, decrypt path.
for (const word of ['R_BACKUP_INCLUDE_USER_INFO','exportIncludeUserInfo','ImportPasswordSheet','confirmDecryptImport','decryptSelected','InputType.Password']) assert.ok(page.includes(word), `Storage page missing encrypted-flow ${word}`);
// Passwords must never be persisted/logged from the page: no preferences writes, no console/Diagnostic logging of the buffers.
assert.ok(!/(console\.(log|info|warn|error)|DiagnosticLogger)[^\n]*(exportPassword|importPassword)/.test(page), 'page must not log password buffers');
for (const word of ['backupImportPreviewCopy','backupImportConfirmDialogCopy','login state','cookies','tokens','overwrite','validateExportPassword']) assert.ok(coord.includes(word), `coordinator missing ${word}`);
for (const name of ['backup_section','export_backup','import_backup','backup_export_subtitle','backup_import_subtitle','backup_include_user_info','backup_set_password','backup_enter_password','backup_error_bad_password']) assert.ok(appStrings.includes(`app.string.${name}`), `AppStrings missing ${name}`);
for (const locale of ['base','en_US','zh_CN','zh_HK','zh_TW']) {
  const s = fs.readFileSync(`${root}/entry/src/main/resources/${locale}/element/string.json`, 'utf8');
  for (const name of ['backup_section','export_backup','import_backup','backup_include_user_info','backup_set_password','backup_unlock']) assert.ok(s.includes(`"${name}"`), `${locale} missing ${name}`);
}
console.log('PASS storage backup UI static');
