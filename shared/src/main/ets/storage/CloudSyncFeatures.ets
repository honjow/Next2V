// Canonical mapping of user-facing cloud-sync "features" to the local RDB tables each one syncs. The
// Settings page renders one toggle per feature (in this array's order); LocalDataCloudSync marks/syncs the
// union of the enabled features' tables PLUS the always-on synced_kv catch-all. Feature keys are persisted
// as preference keys (see CloudSyncSettings) — keep them STABLE; renaming one silently resets a user's choice.

export class CloudSyncFeature {
  static readonly SEARCH_HISTORY: string = 'searchHistory'
  static readonly COLLECTIONS: string = 'collections'
  static readonly RECENT_VIEWS: string = 'recentViews'
  static readonly READ_PROGRESS: string = 'readProgress'
  static readonly MARKS: string = 'marks'
}

export interface CloudSyncFeatureDef {
  key: string
  tables: string[]
}

// Display order on the Settings page == this array order. Each feature groups the tables that back one
// user-visible capability (收藏 = saved topics + nodes; 阅读进度 = read positions + read states; etc.).
export const CLOUD_SYNC_FEATURES: CloudSyncFeatureDef[] = [
  { key: CloudSyncFeature.SEARCH_HISTORY, tables: ['search_history'] },
  {
    key: CloudSyncFeature.COLLECTIONS,
    tables: ['collection_saved_topics', 'collection_saved_nodes'],
  },
  { key: CloudSyncFeature.RECENT_VIEWS, tables: ['collection_viewed_topics'] },
  {
    key: CloudSyncFeature.READ_PROGRESS,
    tables: ['collection_topic_read_positions', 'collection_topic_read_states'],
  },
  { key: CloudSyncFeature.MARKS, tables: ['user_mark_labels', 'user_mark_assignments'] },
]

// Synced whenever cloud sync is enabled, regardless of per-feature toggles: the generic key-value catch-all
// (see SyncedKv) is internal plumbing, not a user-facing feature, so it has no toggle of its own.
export const CLOUD_SYNC_ALWAYS_TABLES: string[] = ['synced_kv']

// The set of local tables to mark/sync given the currently-enabled feature keys. Always-on tables come
// first, then the enabled features in display order; the result is a stable, dedup-free list (each table
// belongs to exactly one feature).
export function cloudSyncTablesForFeatures(enabledKeys: string[]): string[] {
  const tables: string[] = []
  CLOUD_SYNC_ALWAYS_TABLES.forEach((table: string) => tables.push(table))
  CLOUD_SYNC_FEATURES.forEach((def: CloudSyncFeatureDef) => {
    if (enabledKeys.includes(def.key)) {
      def.tables.forEach((table: string) => tables.push(table))
    }
  })
  return tables
}
