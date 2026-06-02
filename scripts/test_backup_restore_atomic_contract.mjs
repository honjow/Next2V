#!/usr/bin/env node
import fs from 'node:fs'
import assert from 'node:assert/strict'

const root = process.cwd()
const service = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupService.ets`, 'utf8')
const adapter = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupLocalDataAdapter.ets`, 'utf8')
const collections = fs.readFileSync(`${root}/shared/src/main/ets/settings/CollectionSettings.ets`, 'utf8')

assert.ok(service.includes('const rollbackSnapshot = await BackupService.createRollbackSnapshot(context, envelope.sections)'), 'restoreBackup must snapshot current local data (scoped to the imported sections) before applying sections')
assert.ok(service.includes('await BackupService.rollbackRestore(context, rollbackSnapshot)'), 'restoreBackup must rollback on section write failure')
// The rollback snapshot only reads account data when the import carries userInfo, so a plaintext
// import never touches credentials on rollback; a userInfo import does roll accounts back.
assert.ok(/sections\.indexOf\('userInfo'\)\s*>=\s*0/.test(service), 'rollback snapshot reads account data only for userInfo imports')
// Format-tolerant: after rollback, restoreBackup returns ok:false with restoredSections:[] (no
// partial restore) and the local-data-restored message. Matches single- or multi-line formatting.
assert.ok(
  /return\s*\{\s*ok:\s*false,\s*restoredSections:\s*\[\],\s*failedSections:\s*\[section\],\s*message:\s*'Backup import failed and local data was restored\.',?\s*\}/s.test(service),
  'restoreBackup must report no restored sections after rollback'
)
assert.ok(!service.includes('const restored: BackupSectionName[] = []'), 'restoreBackup must not expose partial restored sections')
assert.ok(!service.includes('failed.push(section)'), 'restoreBackup must not continue after section failures')
assert.ok(!/catch\s*\(_error\)\s*{\s*failed\.push\(section\)/s.test(service), 'restoreBackup must not swallow section failures and continue')

assert.ok(adapter.includes('await CollectionSettings.restoreBackup(context, section)'), 'BackupLocalDataAdapter must restore collections through CollectionSettings boundary')
assert.ok(!adapter.includes("'@kit.ArkData'") && !adapter.includes('@ohos.data.relationalStore'), 'BackupLocalDataAdapter must not import relationalStore directly')
assert.ok(!adapter.includes('LocalDataStore'), 'BackupLocalDataAdapter must not open LocalDataStore directly')

assert.ok(collections.includes('static async restoreBackup(context: common.UIAbilityContext, section: BackupCollectionsSection): Promise<void>'), 'CollectionSettings must own collection backup restore')
assert.ok(collections.includes('SQL_CLEAR_SAVED_TOPICS') && collections.includes('SQL_CLEAR_TOPIC_READ_STATES'), 'CollectionSettings restore must clear all collection tables through approved boundary')
assert.ok(collections.includes('LocalDataPublisher.touchLocalData()'), 'CollectionSettings restore must publish local data mutation')

console.log('PASS backup restore atomic contract')
