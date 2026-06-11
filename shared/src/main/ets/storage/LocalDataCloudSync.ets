import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectCloudSync } from '../state/CloudSyncState'
import { CloudSyncSettings } from '../settings/CloudSyncSettings'
import { CollectionSettings } from '../settings/CollectionSettings'
import { LocalDataPublisher } from '../settings/LocalDataPublisher'

// Device-cloud sync (端云协同) for the local RDB. A table is synced only when (a) its primary key is stable
// across devices so a last-write-wins merge on *_at columns is safe, AND (b) its cloud data type exists in
// AGC + is declared in arkdata/cloud/cloud_schema.json (all columns no-NOT-NULL). The synced set is no
// longer a fixed list here: it is computed from the user's per-feature toggles (see CloudSyncFeatures /
// CloudSyncSettings.enabledTables). synced_kv is the always-on generic catch-all (see SyncedKv);
// user_mark_assignments uses a composite dedup key (username_key + label_id). Deliberately NOT synced:
// cache_entries (device-local file payloads, re-fetchable) and topic_action_overlays (owner_key not yet
// deterministic per account).

const SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC'

export class LocalDataCloudSync {
  // Signature (joined table list) of the last setDistributedTables call: re-marking is skipped when the
  // selection is unchanged but re-runs when the user flips a feature toggle. Empty = never marked this run.
  private static lastMarkedSignature: string = ''
  private static autoSyncListenerBound: boolean = false

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
    // The synced set follows the user's per-feature toggles; the always-on synced_kv keeps it non-empty.
    const activeTables: string[] = CloudSyncSettings.enabledTables()
    const signature: string = activeTables.join(',')
    if (LocalDataCloudSync.lastMarkedSignature === signature) {
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
          activeTables,
          relationalStore.DistributedType.DISTRIBUTED_CLOUD,
          config,
        )
        LocalDataCloudSync.lastMarkedSignature = signature
        // Observe system-driven auto sync (the real sync path when autoSync:true). Bind the listener once
        // per process — re-marking after a feature toggle must not stack duplicate listeners.
        if (!LocalDataCloudSync.autoSyncListenerBound) {
          LocalDataCloudSync.autoSyncListenerBound = true
          store.on('autoSyncProgress', (progress: relationalStore.ProgressDetails) => {
            DiagnosticLogger.info('cloud_sync', 'cloud_sync_auto_progress', {
              schedule: progress.schedule,
              progressCode: progress.code,
            })
            if (progress.schedule === relationalStore.Progress.SYNC_FINISH) {
              LocalDataCloudSync.logTableDetails('cloud_sync_auto_table_detail', progress)
              LocalDataCloudSync.refreshAfterDownload(context, progress)
              LocalDataCloudSync.recordAutoSyncFinish(context, progress)
            }
          })
        }
        DiagnosticLogger.info('cloud_sync', 'cloud_sync_tables_marked', {
          tableCount: activeTables.length,
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
      {
        errorKind: lastError !== null ? lastError.name || 'Error' : 'Error',
        message: lastError !== null ? lastError.message || '' : '',
      },
      lastError !== null ? lastError : undefined,
    )
    return false
  }

  // Trigger a manual cloud-first sync of the marked tables; resolve with whether it reached progressCode 0
  // and record the outcome in CloudSyncState (surfaced by the Settings "立即同步" row). A `code` of
  // RDB_CLOUD_DISABLED (3) means the system Huawei 云空间 data sync is OFF for this app: the app cannot
  // toggle that switch, so we flag it (cloudDisabled) and Settings shows a "enable it in system settings"
  // hint instead of the generic "sync failed". Local data is unaffected either way.
  static async cloudSyncNow(context: common.UIAbilityContext): Promise<boolean> {
    const state = connectCloudSync()
    state.syncing = true
    try {
      const store = await LocalDataStore.open(context)
      // store.cloudSync's promise resolves once the sync is ACCEPTED, not finished — the real outcome
      // arrives later via the progress callback's SYNC_FINISH event. Resolve on that (with a safety
      // timeout so a never-finishing sync still settles), capturing progress.code at finish. -1 is our
      // sentinel for a timeout / rejected call.
      const code: number = await new Promise<number>((resolve: (value: number) => void) => {
        let settled: boolean = false
        const finish = (result: number): void => {
          if (!settled) {
            settled = true
            resolve(result)
          }
        }
        const timer = setTimeout(() => {
          finish(-1)
        }, 30000)
        store
          .cloudSync(
            relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
            (progress: relationalStore.ProgressDetails) => {
              DiagnosticLogger.info('cloud_sync', 'cloud_sync_progress', {
                schedule: progress.schedule,
                progressCode: progress.code,
              })
              if (progress.schedule === relationalStore.Progress.SYNC_FINISH) {
                clearTimeout(timer)
                LocalDataCloudSync.logTableDetails('cloud_sync_table_detail', progress)
                LocalDataCloudSync.refreshAfterDownload(context, progress)
                finish(progress.code)
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
            finish(-1)
          })
      })
      const ok: boolean = code === 0
      const cloudDisabled: boolean = code === 3
      await CloudSyncSettings.recordLastSync(context, ok, cloudDisabled)
      state.syncing = false
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_done', { ok: ok, progressCode: code })
      return ok
    } catch (error) {
      const e = error as Error
      await CloudSyncSettings.recordLastSync(context, false, false)
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

  // Scheduler path for local-write/foreground follow-up syncs. Re-marking is idempotent and keeps the
  // scheduled path robust after process restart, feature-toggle changes, or a missed startup mark.
  static async runScheduledSync(
    context: common.UIAbilityContext,
    reason: string,
  ): Promise<boolean> {
    const marked = await LocalDataCloudSync.markDistributedTables(context)
    if (!marked) {
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_scheduled_mark_skipped', { reason: reason })
      return false
    }
    return await LocalDataCloudSync.cloudSyncNow(context)
  }

  // Per-table cloud-sync stats from progress.details (keyed by LOCAL table name), logged at SYNC_FINISH.
  // The round's progressCode does NOT reflect per-table outcomes: a table can silently fail to upload
  // (upFail>0, e.g. its AGC cloud data type is missing/mismapped) or never be processed (present:false,
  // e.g. not in the marked set) while the round still returns code 0. This makes that per-table truth
  // visible — grep `cloud_sync_table_detail` for `"table":"collection_saved_nodes"`.
  private static logTableDetails(event: string, progress: relationalStore.ProgressDetails): void {
    const details: Record<string, relationalStore.TableDetails> = progress.details
    if (!details) {
      return
    }
    const tables: string[] = CloudSyncSettings.enabledTables()
    tables.forEach((table: string) => {
      const td: relationalStore.TableDetails | undefined = details[table]
      if (td === undefined || td === null) {
        DiagnosticLogger.info('cloud_sync', event, { table: table, present: false })
        return
      }
      DiagnosticLogger.info('cloud_sync', event, {
        table: table,
        present: true,
        upTotal: td.upload.total,
        upOk: td.upload.successful,
        upFail: td.upload.failed,
        downTotal: td.download.total,
        downOk: td.download.successful,
        downFail: td.download.failed,
      })
    })
  }

  private static recordAutoSyncFinish(
    context: common.UIAbilityContext,
    progress: relationalStore.ProgressDetails,
  ): void {
    const ok: boolean = progress.code === 0
    const cloudDisabled: boolean = progress.code === 3
    CloudSyncSettings.recordLastSync(context, ok, cloudDisabled).catch((error: Error) => {
      DiagnosticLogger.warn(
        'cloud_sync',
        'cloud_sync_auto_record_error',
        { message: error.message || '' },
        error,
      )
    })
  }

  // After a sync round downloads cloud rows STRAIGHT into the RDB (the cloud-sync engine bypasses the
  // app's own write methods that publish counts — saveNode → publishSavedNodeCount etc.), the in-memory
  // LocalContentStats holder is stale, so Me-page counts don't move until the user re-enters a page and it
  // re-queries. Recompute + republish the stats (and bump the local-data signal) so the UI reacts live.
  // Only when something actually downloaded; best-effort, never throws.
  private static refreshAfterDownload(
    context: common.UIAbilityContext,
    progress: relationalStore.ProgressDetails,
  ): void {
    if (!LocalDataCloudSync.hasDownloads(progress)) {
      return
    }
    CollectionSettings.loadLocalContentStats(context).catch((_error: Error) => {})
    LocalDataPublisher.touchLocalData()
  }

  // Sum download.total across the marked tables for this round; >0 means cloud data landed locally.
  private static hasDownloads(progress: relationalStore.ProgressDetails): boolean {
    const details: Record<string, relationalStore.TableDetails> = progress.details
    if (!details) {
      return false
    }
    const tables: string[] = CloudSyncSettings.enabledTables()
    let total: number = 0
    tables.forEach((table: string) => {
      const td: relationalStore.TableDetails | undefined = details[table]
      if (td !== undefined && td !== null) {
        total = total + td.download.total
      }
    })
    return total > 0
  }

  // Touch SQL (no-op self-assignment of a non-PK column) for a synced table. Running it re-fires the
  // AFTER-UPDATE cloud-sync trigger, re-flagging every existing row dirty for upload. '' = skip.
  // Deliberately limited to the small, user-curated "set once" tables (saved nodes/topics, marks, search,
  // KV). The large auto-history tables (viewed topics, read positions/states) are EXCLUDED: they hold
  // hundreds of rows (a one-shot re-upload of all of them would overrun the sync timeout) and they
  // self-heal anyway — every new view/read writes a fresh row that uploads via the ON-CONFLICT fix.
  private static reuploadTouchSql(table: string): string {
    if (table === 'search_history') {
      return 'UPDATE search_history SET searched_at = searched_at'
    }
    if (table === 'synced_kv') {
      return 'UPDATE synced_kv SET updated_at = updated_at'
    }
    if (table === 'collection_saved_topics') {
      return 'UPDATE collection_saved_topics SET saved_at = saved_at'
    }
    if (table === 'collection_saved_nodes') {
      return 'UPDATE collection_saved_nodes SET saved_at = saved_at'
    }
    if (table === 'user_mark_labels') {
      return 'UPDATE user_mark_labels SET updated_at = updated_at'
    }
    if (table === 'user_mark_assignments') {
      return 'UPDATE user_mark_assignments SET updated_at = updated_at'
    }
    return ''
  }

  // One-shot recovery for the `INSERT OR REPLACE` bug: rows written before the ON-CONFLICT fix were never
  // flagged for cloud upload. Re-touch existing rows of the currently-synced tables so they get re-marked
  // dirty and finally upload. Runs once per device, AFTER markDistributedTables (the triggers must exist)
  // and before the sync. Best-effort; never throws.
  static async flushStuckRowsOnce(context: common.UIAbilityContext): Promise<void> {
    try {
      if (await CloudSyncSettings.isReuploadFlushDone(context)) {
        return
      }
      const store = await LocalDataStore.open(context)
      const tables: string[] = CloudSyncSettings.enabledTables()
      let touched: number = 0
      for (const table of tables) {
        const sql: string = LocalDataCloudSync.reuploadTouchSql(table)
        if (!sql) {
          continue
        }
        try {
          await store.executeSql(sql)
          touched = touched + 1
        } catch (error) {
          const e = error as Error
          DiagnosticLogger.warn(
            'cloud_sync',
            'cloud_sync_reupload_touch_error',
            { table: table, message: e.message || '' },
            e,
          )
        }
      }
      await CloudSyncSettings.markReuploadFlushDone(context)
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_reupload_flush_done', { touched: touched })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn(
        'cloud_sync',
        'cloud_sync_reupload_flush_error',
        { message: e.message || '' },
        e,
      )
    }
  }

  // Re-mark the distributed-table set to match the current per-feature toggles, then run a sync. Called
  // when the user flips a feature toggle while cloud sync is already on (master enabled + permission
  // granted), so it skips the permission prompt. Never throws.
  static async applyFeatureSelection(context: common.UIAbilityContext): Promise<void> {
    const marked = await LocalDataCloudSync.markDistributedTables(context)
    if (!marked) {
      return
    }
    await LocalDataCloudSync.flushStuckRowsOnce(context)
    await LocalDataCloudSync.cloudSyncNow(context)
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
    // One-time recovery of rows stuck by the old INSERT OR REPLACE upsert (must run after the tables are
    // marked distributed so the cloud-sync triggers exist).
    await LocalDataCloudSync.flushStuckRowsOnce(context)
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
