import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectCloudSync } from '../state/CloudSyncState'

// Device-cloud sync (端云协同) for the local RDB. A table is synced only when (a) its primary key is stable
// across devices so a last-write-wins merge on *_at columns is safe, AND (b) its cloud data type exists in
// AGC + is declared in arkdata/cloud/cloud_schema.json. synced_kv is the generic catch-all (see SyncedKv).
// Deliberately NOT synced: cache_entries (device-local file payloads, re-fetchable) and topic_action_overlays
// (its owner_key is not yet deterministic per account). collection_* / user_mark_* are candidates for a later
// phase — each needs its NOT NULL dropped, an AGC data type, and a cloud_schema.json entry before listing here.
const CLOUD_SYNCED_TABLES: string[] = [
  'search_history',
  'synced_kv',
]

const SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC'

export class LocalDataCloudSync {
  private static distributedMarked: boolean = false

  // Startup bootstrap: migrate the legacy 'V2Next.db' store into the renamed 'Next2V.db' store exactly
  // once, before any page or cloud-sync consumer touches the DB. Routed through this class (already a
  // LocalDataStore consumer) so EntryAbility need not reference LocalDataStore directly. Never throws.
  static async runStartupMigration(context: common.UIAbilityContext): Promise<void> {
    await LocalDataStore.runLegacyDbMigration(context)
  }

  // Request the user-grant DISTRIBUTED_DATASYNC permission that setDistributedTables requires. Pops the
  // system dialog only when not already decided; returns true when granted.
  static async ensurePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const at: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
      const result = await at.requestPermissionsFromUser(context, [SYNC_PERMISSION])
      const authResults: number[] = result.authResults
      const granted = authResults.length > 0 && authResults[0] === 0
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_permission', { granted: granted })
      return granted
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'cloud_sync',
        'cloud_sync_permission_error',
        { errorKind: e.name || 'Error' },
        e,
      )
      return false
    }
  }

  // Mark the syncable tables as cloud-distributed with autoSync on. Idempotent per process; the cloud
  // backend identity is the system Huawei account (no in-app login). Requires the permission granted.
  static async markDistributedTables(context: common.UIAbilityContext): Promise<boolean> {
    if (LocalDataCloudSync.distributedMarked) {
      return true
    }
    // Retry: at first launch after the V2Next.db -> Next2V.db rename, this runs right after the legacy
    // migration's attach/detach/deleteRdbStore, and setDistributedTables can transiently fail while the
    // distributeddata service is still busy. A couple of spaced retries let that settle.
    let attempt: number = 0
    let lastError: Error | null = null
    while (attempt < 3) {
      attempt = attempt + 1
      try {
        const store = await LocalDataStore.open(context)
        const config: relationalStore.DistributedConfig = { autoSync: true }
        await store.setDistributedTables(
          CLOUD_SYNCED_TABLES,
          relationalStore.DistributedType.DISTRIBUTED_CLOUD,
          config,
        )
        LocalDataCloudSync.distributedMarked = true
        // Observe system-driven auto sync (the real sync path when autoSync:true) so we can see whether
        // background sync succeeds even if a manual cloudSync fired too early returns CLOUD_DISABLED.
        store.on('autoSyncProgress', (progress: relationalStore.ProgressDetails) => {
          DiagnosticLogger.info('cloud_sync', 'cloud_sync_auto_progress', {
            schedule: progress.schedule,
            progressCode: progress.code,
          })
        })
        DiagnosticLogger.info('cloud_sync', 'cloud_sync_tables_marked', {
          tableCount: CLOUD_SYNCED_TABLES.length,
          attempt: attempt,
        })
        return true
      } catch (error) {
        lastError = error as Error
        DiagnosticLogger.warn('cloud_sync', 'cloud_sync_mark_retry', {
          attempt: attempt,
          errorKind: lastError.name || 'Error',
          message: lastError.message || '',
        })
        await LocalDataCloudSync.delay(1500)
      }
    }
    DiagnosticLogger.warn(
      'cloud_sync',
      'cloud_sync_mark_error',
      { errorKind: lastError !== null ? lastError.name || 'Error' : 'Error', message: lastError !== null ? lastError.message || '' : '' },
      lastError !== null ? lastError : undefined,
    )
    return false
  }

  // Trigger a manual cloud-first sync of the marked tables; resolve with whether it reached progressCode 0
  // and record the outcome in CloudSyncState (surfaced by the Settings "立即同步" row). A `code` of
  // RDB_CLOUD_DISABLED (3) means cloud sync is not enabled at the system level — harmless; app keeps
  // working locally.
  static async cloudSyncNow(context: common.UIAbilityContext): Promise<boolean> {
    const state = connectCloudSync()
    state.syncing = true
    try {
      const store = await LocalDataStore.open(context)
      // store.cloudSync's promise resolves once the sync is ACCEPTED, not finished — the real outcome
      // arrives later via the progress callback's SYNC_FINISH event. Resolve on that (with a safety
      // timeout so a never-finishing sync still settles), reading progress.code at finish.
      const ok: boolean = await new Promise<boolean>((resolve: (value: boolean) => void) => {
        let settled: boolean = false
        const finish = (result: boolean): void => {
          if (!settled) {
            settled = true
            resolve(result)
          }
        }
        const timer = setTimeout(() => {
          finish(false)
        }, 30000)
        store
          .cloudSync(
            relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
            (progress: relationalStore.ProgressDetails) => {
              DiagnosticLogger.info('cloud_sync', 'cloud_sync_progress', {
                schedule: progress.schedule,
                progressCode: progress.code,
              })
              if (progress.schedule === relationalStore.Progress.SYNC_FINISH) {
                clearTimeout(timer)
                finish(progress.code === 0)
              }
            },
          )
          .catch((error: Error) => {
            clearTimeout(timer)
            DiagnosticLogger.warn(
              'cloud_sync',
              'cloud_sync_error',
              { errorKind: error.name || 'Error', message: error.message || '' },
              error,
            )
            finish(false)
          })
      })
      state.lastSyncAt = Date.now()
      state.lastSyncOk = ok
      state.syncing = false
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_done', { ok: ok })
      return ok
    } catch (error) {
      const e = error as Error
      state.lastSyncAt = Date.now()
      state.lastSyncOk = false
      state.syncing = false
      DiagnosticLogger.warn(
        'cloud_sync',
        'cloud_sync_error',
        { errorKind: e.name || 'Error', message: e.message || '' },
        e,
      )
      return false
    }
  }

  // One-shot best-effort enable + sync, safe to call at startup. Never throws. (Phase 1 wires this at
  // app launch for on-device validation; Phase 2 will gate it behind a user "云同步" setting + a manual
  // sync button instead of auto-requesting at startup.)
  static async tryEnableAndSync(context: common.UIAbilityContext): Promise<void> {
    const granted = await LocalDataCloudSync.ensurePermission(context)
    if (!granted) {
      return
    }
    const marked = await LocalDataCloudSync.markDistributedTables(context)
    if (!marked) {
      return
    }
    // Calling cloudSync immediately after setDistributedTables returns CLOUD_DISABLED (cloud session not
    // ready yet). Give the cloud sync session time to establish, then trigger a manual sync (Phase-1
    // diagnostic — production should rely on autoSync + an explicit "立即同步" user action).
    await LocalDataCloudSync.delay(8000)
    await LocalDataCloudSync.cloudSyncNow(context)
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), ms)
    })
  }
}
