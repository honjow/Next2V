#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

const scheduler = read('shared/src/main/ets/storage/CloudSyncScheduler.ets')
const localDataCloudSync = read('shared/src/main/ets/storage/LocalDataCloudSync.ets')
const entryAbility = read('entry/src/main/ets/entryability/EntryAbility.ets')
const index = read('shared/src/main/ets/Index.ets')
const search = read('shared/src/main/ets/settings/SearchSettings.ets')
const collection = read('shared/src/main/ets/settings/CollectionSettings.ets')
const userMarks = read('shared/src/main/ets/settings/UserMarkSettings.ets')
const syncedKv = read('shared/src/main/ets/storage/SyncedKv.ets')

for (const snippet of [
  'export class CloudSyncScheduler',
  'export type CloudSyncExecutor',
  'LOCAL_WRITE_DEBOUNCE_MS: number = 15000',
  'FOREGROUND_DEBOUNCE_MS: number = 3000',
  'MIN_ATTEMPT_INTERVAL_MS: number = 45000',
  'RETRY_BASE_MS: number = 60000',
  'RETRY_MAX_MS: number = 300000',
  'static bindExecutor',
  'static rememberContext',
  'static requestAfterLocalWrite',
  'static requestAfterForeground',
  'CloudSyncSettings.isEnabled()',
  'connectCloudSync().syncing',
  'cloud_sync_scheduled_start',
  'cloud_sync_scheduled_done',
]) {
  assert(scheduler.includes(snippet), `CloudSyncScheduler missing contract: ${snippet}`)
}

assert(
  !scheduler.includes('LocalDataCloudSync'),
  'CloudSyncScheduler must not import LocalDataCloudSync; EntryAbility binds the executor to avoid shared-layer cycles',
)

assert(
  index.includes("export { CloudSyncScheduler } from './storage/CloudSyncScheduler'"),
  'shared index must export CloudSyncScheduler for EntryAbility',
)
assert(
  index.includes("export type { CloudSyncExecutor } from './storage/CloudSyncScheduler'"),
  'shared index must export CloudSyncExecutor type',
)

assert(
  entryAbility.includes('CloudSyncScheduler.bindExecutor') &&
    entryAbility.includes('LocalDataCloudSync.runScheduledSync(context, reason)'),
  'EntryAbility must bind LocalDataCloudSync as the scheduler executor',
)
assert(
  entryAbility.includes('onForeground(): void') &&
    entryAbility.includes("CloudSyncScheduler.requestAfterForeground(this.context, 'foreground')"),
  'EntryAbility must request a foreground follow-up sync',
)
assert(
  entryAbility.includes('lastStartupSyncKickoffAt') &&
    entryAbility.includes('sinceStartupSyncMs < 60000'),
  'foreground sync must avoid duplicating the startup sync kickoff',
)

assert(
  localDataCloudSync.includes('static async runScheduledSync') &&
    /runScheduledSync[\s\S]*markDistributedTables\(context\)[\s\S]*cloudSyncNow\(context\)/.test(localDataCloudSync),
  'LocalDataCloudSync.runScheduledSync must re-mark tables before scheduled sync',
)
assert(
  localDataCloudSync.includes('recordAutoSyncFinish(context, progress)') &&
    localDataCloudSync.includes('CloudSyncSettings.recordLastSync(context, ok, cloudDisabled)'),
  'autoSync finish must update the last-sync status shown in Settings',
)

for (const source of [
  ['SearchSettings', search, ['search_history', 'search_history_clear']],
  [
    'CollectionSettings',
    collection,
    [
      'collection_saved_topics',
      'collection_saved_nodes',
      'collection_viewed_topics',
      'collection_topic_read_positions',
      'collection_topic_read_states',
      'collection_clear_all',
      'collection_restore_backup',
    ],
  ],
  [
    'UserMarkSettings',
    userMarks,
    [
      'user_marks',
      'user_mark_assignments',
      'user_marks_restore_backup',
      'user_marks_clear_all',
    ],
  ],
  ['SyncedKv', syncedKv, ['synced_kv']],
]) {
  const label = source[0]
  const text = source[1]
  const reasons = source[2]
  assert(
    text.includes('CloudSyncScheduler.requestAfterLocalWrite'),
    `${label} must request cloud sync after cloud-synced local writes`,
  )
  for (const reason of reasons) {
    assert(text.includes(`'${reason}'`), `${label} missing scheduled sync reason: ${reason}`)
  }
}

console.log('cloud sync scheduler contract OK')
