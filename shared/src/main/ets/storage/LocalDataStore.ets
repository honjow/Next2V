import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export const LOCAL_DATA_DB_NAME: string = 'Next2V.db'
// Legacy local store name before the 2026 "Next2V" rename. The file used to be 'V2Next.db' (its cloud
// 本地数据库名称 / schema database.name resolved to 'V2Next'); we renamed the store to 'Next2V.db' to unify
// with the AGC 端云协同 container name 'Next2V'. Existing installs still hold a 'V2Next.db' file whose rows
// must move into the new store once on startup — see LocalDataStore.runLegacyDbMigration.
const LEGACY_LOCAL_DATA_DB_NAME: string = 'V2Next.db'
export const LOCAL_DATA_SCHEMA_VERSION: number = 6
export const LOCAL_DATA_SCHEMA_META_TABLE: string = 'schema_meta'

export const SQL_CREATE_SCHEMA_META_TABLE: string = 'CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)'
// NOTE: cloud sync (端云协同) forbids NOT NULL on synced-table columns — "ArkData 本地表所有字段定义不能
// 设置 NOT NULL 属性" (端云数据同步云侧环境部署指导). search_history is the Phase-1 cloud-synced table,
// so its columns must omit NOT NULL or the cloud schema won't match and sync stays disabled.
export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY, searched_at INTEGER)'
export const SQL_CREATE_SEARCH_HISTORY_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history (searched_at DESC)'
export const SQL_CREATE_CACHE_ENTRIES_TABLE: string = 'CREATE TABLE IF NOT EXISTS cache_entries (cache_key TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, payload_text TEXT, payload_path TEXT, cached_at INTEGER NOT NULL, accessed_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, size INTEGER NOT NULL, etag TEXT, payload_hash TEXT)'
export const SQL_CREATE_CACHE_ENTRIES_KIND_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_kind ON cache_entries (kind)'
export const SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_expires_at ON cache_entries (expires_at)'
export const SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_accessed_at ON cache_entries (accessed_at)'
export const SQL_CREATE_COLLECTION_SAVED_TOPICS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_saved_topics (topic_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL, node_name TEXT NOT NULL, node_title TEXT NOT NULL, username TEXT NOT NULL, avatar TEXT, member_pro INTEGER, created INTEGER NOT NULL, replies INTEGER, saved_at INTEGER NOT NULL)'
export const SQL_CREATE_COLLECTION_SAVED_TOPICS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_saved_topics_saved_at ON collection_saved_topics (saved_at DESC, topic_id DESC)'
export const SQL_CREATE_COLLECTION_SAVED_NODES_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_saved_nodes (node_name TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, topics INTEGER NOT NULL, avatar_mini TEXT, avatar_normal TEXT, avatar_large TEXT, saved_at INTEGER NOT NULL)'
export const SQL_CREATE_COLLECTION_SAVED_NODES_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_saved_nodes_saved_at ON collection_saved_nodes (saved_at DESC, node_name ASC)'
export const SQL_CREATE_COLLECTION_VIEWED_TOPICS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_viewed_topics (topic_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL, node_name TEXT NOT NULL, node_title TEXT NOT NULL, username TEXT NOT NULL, avatar TEXT, member_pro INTEGER, replies INTEGER, viewed_at INTEGER NOT NULL)'
export const SQL_CREATE_COLLECTION_VIEWED_TOPICS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_viewed_topics_viewed_at ON collection_viewed_topics (viewed_at DESC, topic_id DESC)'
export const SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_topic_read_positions (topic_id INTEGER PRIMARY KEY NOT NULL, floor INTEGER NOT NULL, updated_at INTEGER NOT NULL)'
export const SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_positions_updated_at ON collection_topic_read_positions (updated_at DESC, topic_id DESC)'
export const SQL_CREATE_COLLECTION_TOPIC_READ_STATES_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_topic_read_states (topic_id INTEGER PRIMARY KEY NOT NULL, touched_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)'
export const SQL_CREATE_COLLECTION_TOPIC_READ_STATES_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_states_updated_at ON collection_topic_read_states (updated_at DESC, topic_id DESC)'
export const SQL_CREATE_TOPIC_ACTION_OVERLAYS_TABLE: string = 'CREATE TABLE IF NOT EXISTS topic_action_overlays (owner_key TEXT NOT NULL, base_url TEXT NOT NULL, account_id TEXT NOT NULL, login_mode TEXT NOT NULL, topic_id INTEGER NOT NULL, favorite_known INTEGER NOT NULL DEFAULT 0, favorite_value INTEGER NOT NULL DEFAULT 0, topic_thank_known INTEGER NOT NULL DEFAULT 0, topic_thank_value INTEGER NOT NULL DEFAULT 0, reply_thanked_ids_json TEXT NOT NULL DEFAULT \'[]\', reply_thank_counts_json TEXT NOT NULL DEFAULT \'{}\', source TEXT NOT NULL, updated_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, PRIMARY KEY(owner_key, topic_id))'
export const SQL_CREATE_TOPIC_ACTION_OVERLAYS_EXPIRES_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_topic_action_overlays_expires_at ON topic_action_overlays (expires_at)'
export const SQL_CREATE_TOPIC_ACTION_OVERLAYS_ACCOUNT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_topic_action_overlays_account ON topic_action_overlays (base_url, account_id)'
export const SQL_CREATE_USER_MARK_LABELS_TABLE: string = 'CREATE TABLE IF NOT EXISTS user_mark_labels (label_id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, color TEXT NOT NULL, sort_order INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)'
export const SQL_CREATE_USER_MARK_LABELS_SORT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_labels_sort ON user_mark_labels (sort_order ASC, updated_at DESC)'
export const SQL_CREATE_USER_MARK_ASSIGNMENTS_TABLE: string = 'CREATE TABLE IF NOT EXISTS user_mark_assignments (username_key TEXT NOT NULL, username TEXT NOT NULL, label_id TEXT NOT NULL, assigned_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(username_key, label_id))'
export const SQL_CREATE_USER_MARK_ASSIGNMENTS_USERNAME_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_username ON user_mark_assignments (username_key, assigned_at ASC)'
export const SQL_CREATE_USER_MARK_ASSIGNMENTS_LABEL_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_label ON user_mark_assignments (label_id)'
// Generic cloud-syncable key-value "catch-all" for scattered small data (feature flags / small config),
// so new misc data needs ZERO new local table + ZERO new AGC data type — just write a row. kv_key is
// "<namespace>:<key>"; value is a JSON string; no NOT NULL (端云协同 forbids it on synced columns).
export const SQL_CREATE_SYNCED_KV_TABLE: string = 'CREATE TABLE IF NOT EXISTS synced_kv (kv_key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)'
export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\'schema_version\', \'6\')'

// One-time legacy-store (V2Next.db -> Next2V.db) migration metadata. The breadcrumb is a schema_meta row
// (not a static flag) because open() is re-entered by ~6 callers; only a persisted row makes the guard
// survive across them and across process restarts. ALL data tables are copied (incl. the user_mark_*
// tables, so marks survive the rename; cache_entries is re-fetchable but copied too for continuity);
// schema_meta itself is NOT copied (it carries the new store's own version + breadcrumb).
const LEGACY_MIGRATION_BREADCRUMB_KEY: string = 'legacy_v2next_db_migrated'
const LEGACY_ATTACH_ALIAS: string = 'legacy_v2next'
const LEGACY_MIGRATION_TABLES: string[] = [
  'search_history',
  'collection_saved_topics',
  'collection_saved_nodes',
  'collection_viewed_topics',
  'collection_topic_read_positions',
  'collection_topic_read_states',
  'topic_action_overlays',
  'user_mark_labels',
  'user_mark_assignments',
  'synced_kv',
  'cache_entries',
]

const LOCAL_DATA_STORE_CONFIG: relationalStore.StoreConfig = {
  name: LOCAL_DATA_DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S3,
}

export class LocalDataStore {
  static async open(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, LOCAL_DATA_STORE_CONFIG)
    await store.execute(SQL_CREATE_SCHEMA_META_TABLE)
    await store.execute(SQL_CREATE_SEARCH_HISTORY_TABLE)
    await store.execute(SQL_CREATE_SEARCH_HISTORY_INDEX)
    await store.execute(SQL_CREATE_CACHE_ENTRIES_TABLE)
    await store.execute(SQL_CREATE_CACHE_ENTRIES_KIND_INDEX)
    await store.execute(SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX)
    await store.execute(SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX)
    await store.execute(SQL_CREATE_COLLECTION_SAVED_TOPICS_TABLE)
    await store.execute(SQL_CREATE_COLLECTION_SAVED_TOPICS_INDEX)
    await store.execute(SQL_CREATE_COLLECTION_SAVED_NODES_TABLE)
    await store.execute(SQL_CREATE_COLLECTION_SAVED_NODES_INDEX)
    await store.execute(SQL_CREATE_COLLECTION_VIEWED_TOPICS_TABLE)
    await store.execute(SQL_CREATE_COLLECTION_VIEWED_TOPICS_INDEX)
    await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_TABLE)
    await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_INDEX)
    await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_STATES_TABLE)
    await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_STATES_INDEX)
    await store.execute(SQL_CREATE_TOPIC_ACTION_OVERLAYS_TABLE)
    await store.execute(SQL_CREATE_TOPIC_ACTION_OVERLAYS_EXPIRES_AT_INDEX)
    await store.execute(SQL_CREATE_TOPIC_ACTION_OVERLAYS_ACCOUNT_INDEX)
    await store.execute(SQL_CREATE_USER_MARK_LABELS_TABLE)
    await store.execute(SQL_CREATE_USER_MARK_LABELS_SORT_INDEX)
    await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_TABLE)
    await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_USERNAME_INDEX)
    await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_LABEL_INDEX)
    await store.execute(SQL_CREATE_SYNCED_KV_TABLE)
    await store.execute(SQL_UPSERT_SCHEMA_VERSION)
    if (store.version !== LOCAL_DATA_SCHEMA_VERSION) {
      store.version = LOCAL_DATA_SCHEMA_VERSION
    }
    return store
  }

  // Once-per-install migration of all local rows from the renamed-away 'V2Next.db' store into the current
  // 'Next2V.db' store, preserving existing users' collections / read state / search history across the
  // store rename. MUST run as a startup bootstrap BEFORE any page or cloud-sync consumer opens the store,
  // so the attach below never races a live ResultSet (attach requires all ResultSets closed). Idempotent
  // via a schema_meta breadcrumb; the per-table copy + breadcrumb commit in ONE transaction, so a crash
  // rolls back and the next launch retries cleanly. Never throws to the caller.
  static async runLegacyDbMigration(context: common.UIAbilityContext): Promise<void> {
    let store: relationalStore.RdbStore | null = null
    let attached: boolean = false
    try {
      store = await LocalDataStore.open(context)
      if (await LocalDataStore.isLegacyMigrationDone(store)) {
        return
      }
      // Attach the legacy store BY NAME — never a hand-built filesystem path, which is not verified across
      // device storage areas; a false "missing" would write the breadcrumb and permanently strand the
      // user's data. attach throws when the legacy DB cannot be opened (i.e. it does not exist).
      const legacyConfig: relationalStore.StoreConfig = {
        name: LEGACY_LOCAL_DATA_DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S3,
      }
      try {
        await store.attach(context, legacyConfig, LEGACY_ATTACH_ALIAS, 30)
        attached = true
      } catch (error) {
        DiagnosticLogger.info('storage', 'legacy_db_absent', {
          code: (error as BusinessError).code,
        })
      }
      if (!attached) {
        // Fresh install (no legacy DB) -> nothing to migrate; mark done so we don't re-probe every launch.
        await LocalDataStore.writeLegacyMigrationBreadcrumb(store)
        return
      }
      const legacyTables: string[] = await LocalDataStore.listAttachedTables(
        store,
        LEGACY_ATTACH_ALIAS,
      )
      let copiedTables: number = 0
      if (legacyTables.length > 0) {
        store.beginTransaction()
        try {
          for (const table of LEGACY_MIGRATION_TABLES) {
            if (legacyTables.indexOf(table) >= 0) {
              await store.execute(
                'INSERT OR IGNORE INTO main.' +
                  table +
                  ' SELECT * FROM ' +
                  LEGACY_ATTACH_ALIAS +
                  '.' +
                  table,
              )
              copiedTables = copiedTables + 1
            }
          }
          // Breadcrumb committed atomically with the copy: all-or-nothing, no half-migrated state.
          const breadcrumbArgs: Array<relationalStore.ValueType> = [
            LEGACY_MIGRATION_BREADCRUMB_KEY,
            '1',
          ]
          await store.execute(
            'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (?, ?)',
            breadcrumbArgs,
          )
          store.commit()
        } catch (copyError) {
          store.rollBack()
          throw copyError as Error
        }
      } else {
        await LocalDataStore.writeLegacyMigrationBreadcrumb(store)
      }
      await store.detach(LEGACY_ATTACH_ALIAS)
      attached = false
      DiagnosticLogger.info('storage', 'legacy_db_migrated', { tables: copiedTables })
      // Best-effort cleanup now that the copy is committed and the file is detached. deleteRdbStore also
      // removes the -wal/-shm sidecars that a bare file unlink would orphan.
      try {
        await relationalStore.deleteRdbStore(context, LEGACY_LOCAL_DATA_DB_NAME)
      } catch (deleteError) {
        DiagnosticLogger.warn('storage', 'legacy_db_delete_failed', {
          code: (deleteError as BusinessError).code,
        })
      }
    } catch (error) {
      // Leave the breadcrumb unset so a transient failure retries next launch; user data stays safe.
      DiagnosticLogger.warn('storage', 'legacy_db_migration_error', {
        code: (error as BusinessError).code,
      })
      if (store !== null && attached) {
        // Detach to restore WAL mode on the surviving store before giving up.
        try {
          await store.detach(LEGACY_ATTACH_ALIAS)
        } catch (detachError) {}
      }
    }
  }

  private static async isLegacyMigrationDone(store: relationalStore.RdbStore): Promise<boolean> {
    const args: Array<relationalStore.ValueType> = [LEGACY_MIGRATION_BREADCRUMB_KEY]
    const resultSet = await store.querySql('SELECT value FROM schema_meta WHERE key = ?', args)
    try {
      return resultSet.goToFirstRow()
    } finally {
      resultSet.close()
    }
  }

  private static async writeLegacyMigrationBreadcrumb(
    store: relationalStore.RdbStore,
  ): Promise<void> {
    const args: Array<relationalStore.ValueType> = [LEGACY_MIGRATION_BREADCRUMB_KEY, '1']
    await store.execute('INSERT OR REPLACE INTO schema_meta (key, value) VALUES (?, ?)', args)
  }

  // Tables present in an attached database, so an empty/partial legacy DB is handled without a per-table
  // "no such table" throw. The ResultSet is read and closed here, before any attach/detach/transaction.
  private static async listAttachedTables(
    store: relationalStore.RdbStore,
    alias: string,
  ): Promise<string[]> {
    const names: string[] = []
    const resultSet = await store.querySql(
      'SELECT name FROM ' + alias + ".sqlite_master WHERE type = 'table'",
    )
    try {
      while (resultSet.goToNextRow()) {
        names.push(resultSet.getString(resultSet.getColumnIndex('name')))
      }
    } finally {
      resultSet.close()
    }
    return names
  }
}
