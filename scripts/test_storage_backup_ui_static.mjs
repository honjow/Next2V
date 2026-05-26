import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = process.cwd();
const page = fs.readFileSync(`${root}/feature/settings/src/main/ets/pages/StorageSettingsPage.ets`, 'utf8');
const coord = fs.readFileSync(`${root}/feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets`, 'utf8');
const appStrings = fs.readFileSync(`${root}/shared/src/main/ets/i18n/AppStrings.ets`, 'utf8');
for (const word of ['BackupFilePickerCoordinator','BackupSection','confirmExportBackup','selectImportBackup','confirmImportBackup','R_EXPORT_BACKUP','R_IMPORT_BACKUP']) assert.ok(page.includes(word), `Storage page missing ${word}`);
for (const word of ['backupExportDialogCopy','backupImportPreviewCopy','backupImportConfirmDialogCopy','login state','cookies','tokens','overwrite']) assert.ok(coord.includes(word), `coordinator missing ${word}`);
for (const name of ['backup_section','export_backup','import_backup','backup_export_subtitle','backup_import_subtitle']) assert.ok(appStrings.includes(`app.string.${name}`), `AppStrings missing ${name}`);
for (const locale of ['base','en_US','zh_CN','zh_HK','zh_TW']) {
  const s = fs.readFileSync(`${root}/entry/src/main/resources/${locale}/element/string.json`, 'utf8');
  for (const name of ['backup_section','export_backup','import_backup']) assert.ok(s.includes(`"${name}"`), `${locale} missing ${name}`);
}
console.log('PASS storage backup UI static');
