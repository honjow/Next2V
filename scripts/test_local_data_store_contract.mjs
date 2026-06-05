#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const exists = (rel) => fs.existsSync(path.join(repo, rel))
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

const localDataRel = 'shared/src/main/ets/storage/LocalDataStore.ets'
assert(exists(localDataRel), 'LocalDataStore.ets must exist under shared/src/main/ets/storage')
const localDataText = read(localDataRel)

const requiredSnippets = [
  "import { common } from '@kit.AbilityKit'",
  "import { relationalStore } from '@kit.ArkData'",
  "export const LOCAL_DATA_DB_NAME: string = 'Next2V.db'",
  'export const LOCAL_DATA_SCHEMA_VERSION: number = 6',
  "export const LOCAL_DATA_SCHEMA_META_TABLE: string = 'schema_meta'",
  "export const SQL_CREATE_SCHEMA_META_TABLE: string = 'CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)'",
  "export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY, searched_at INTEGER)'",
  "export const SQL_CREATE_SEARCH_HISTORY_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history (searched_at DESC)'",
  "export const SQL_CREATE_CACHE_ENTRIES_TABLE: string = 'CREATE TABLE IF NOT EXISTS cache_entries (cache_key TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, payload_text TEXT, payload_path TEXT, cached_at INTEGER NOT NULL, accessed_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, size INTEGER NOT NULL, etag TEXT, payload_hash TEXT)'",
  "export const SQL_CREATE_CACHE_ENTRIES_KIND_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_kind ON cache_entries (kind)'",
  "export const SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_expires_at ON cache_entries (expires_at)'",
  "export const SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_accessed_at ON cache_entries (accessed_at)'",
  "export const SQL_CREATE_COLLECTION_SAVED_TOPICS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_saved_topics (topic_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL, node_name TEXT NOT NULL, node_title TEXT NOT NULL, username TEXT NOT NULL, avatar TEXT, member_pro INTEGER, created INTEGER NOT NULL, replies INTEGER, saved_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_COLLECTION_SAVED_TOPICS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_saved_topics_saved_at ON collection_saved_topics (saved_at DESC, topic_id DESC)'",
  "export const SQL_CREATE_COLLECTION_SAVED_NODES_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_saved_nodes (node_name TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, topics INTEGER NOT NULL, avatar_mini TEXT, avatar_normal TEXT, avatar_large TEXT, saved_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_COLLECTION_SAVED_NODES_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_saved_nodes_saved_at ON collection_saved_nodes (saved_at DESC, node_name ASC)'",
  "export const SQL_CREATE_COLLECTION_VIEWED_TOPICS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_viewed_topics (topic_id INTEGER PRIMARY KEY NOT NULL, title TEXT NOT NULL, node_name TEXT NOT NULL, node_title TEXT NOT NULL, username TEXT NOT NULL, avatar TEXT, member_pro INTEGER, replies INTEGER, viewed_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_COLLECTION_VIEWED_TOPICS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_viewed_topics_viewed_at ON collection_viewed_topics (viewed_at DESC, topic_id DESC)'",
  "export const SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_topic_read_positions (topic_id INTEGER PRIMARY KEY NOT NULL, floor INTEGER NOT NULL, updated_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_positions_updated_at ON collection_topic_read_positions (updated_at DESC, topic_id DESC)'",
  "export const SQL_CREATE_COLLECTION_TOPIC_READ_STATES_TABLE: string = 'CREATE TABLE IF NOT EXISTS collection_topic_read_states (topic_id INTEGER PRIMARY KEY NOT NULL, touched_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_COLLECTION_TOPIC_READ_STATES_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_states_updated_at ON collection_topic_read_states (updated_at DESC, topic_id DESC)'",
  "export const SQL_CREATE_USER_MARK_LABELS_TABLE: string = 'CREATE TABLE IF NOT EXISTS user_mark_labels (label_id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, color TEXT NOT NULL, sort_order INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_USER_MARK_LABELS_SORT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_labels_sort ON user_mark_labels (sort_order ASC, updated_at DESC)'",
  "export const SQL_CREATE_USER_MARK_ASSIGNMENTS_TABLE: string = 'CREATE TABLE IF NOT EXISTS user_mark_assignments (username_key TEXT NOT NULL, username TEXT NOT NULL, label_id TEXT NOT NULL, assigned_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(username_key, label_id))'",
  "export const SQL_CREATE_USER_MARK_ASSIGNMENTS_USERNAME_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_username ON user_mark_assignments (username_key, assigned_at ASC)'",
  "export const SQL_CREATE_USER_MARK_ASSIGNMENTS_LABEL_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_label ON user_mark_assignments (label_id)'",
  "export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\\'schema_version\\', \\'6\\')'",
  'securityLevel: relationalStore.SecurityLevel.S3',
  'relationalStore.getRdbStore(context, LOCAL_DATA_STORE_CONFIG)',
  'await store.execute(SQL_CREATE_SCHEMA_META_TABLE)',
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_TABLE)',
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_TABLE)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_KIND_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX)',
  'await store.execute(SQL_CREATE_COLLECTION_SAVED_TOPICS_TABLE)',
  'await store.execute(SQL_CREATE_COLLECTION_SAVED_TOPICS_INDEX)',
  'await store.execute(SQL_CREATE_COLLECTION_SAVED_NODES_TABLE)',
  'await store.execute(SQL_CREATE_COLLECTION_SAVED_NODES_INDEX)',
  'await store.execute(SQL_CREATE_COLLECTION_VIEWED_TOPICS_TABLE)',
  'await store.execute(SQL_CREATE_COLLECTION_VIEWED_TOPICS_INDEX)',
  'await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_TABLE)',
  'await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_POSITIONS_INDEX)',
  'await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_STATES_TABLE)',
  'await store.execute(SQL_CREATE_COLLECTION_TOPIC_READ_STATES_INDEX)',
  'await store.execute(SQL_CREATE_USER_MARK_LABELS_TABLE)',
  'await store.execute(SQL_CREATE_USER_MARK_LABELS_SORT_INDEX)',
  'await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_TABLE)',
  'await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_USERNAME_INDEX)',
  'await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_LABEL_INDEX)',
  'await store.execute(SQL_UPSERT_SCHEMA_VERSION)',
  'store.version = LOCAL_DATA_SCHEMA_VERSION',
  'return store',
]
for (const snippet of requiredSnippets) {
  assert(localDataText.includes(snippet), `LocalDataStore contract missing snippet: ${snippet}`)
}
assert(/export\s+class\s+LocalDataStore/.test(localDataText), 'LocalDataStore class must be exported')
assert(/static\s+async\s+open\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<\s*relationalStore\.RdbStore\s*>/.test(localDataText), 'LocalDataStore.open(context) signature missing')
assert(!localDataText.includes('CollectionSettings'), 'LocalDataStore must not import business collection settings')
assert(!localDataText.includes('DraftSettings'), 'LocalDataStore skeleton must not wire drafts')
assert(!localDataText.includes('SearchSettings'), 'LocalDataStore must not know SearchSettings')
assert(!localDataText.includes('CacheSettings'), 'LocalDataStore must not know CacheSettings')

const indexText = read('shared/src/main/ets/Index.ets')
assert(/export\s+\{\s*LocalDataStore,\s*LOCAL_DATA_DB_NAME,\s*LOCAL_DATA_SCHEMA_VERSION,\s*\}\s+from\s+'\.\/storage\/LocalDataStore'/.test(indexText), 'shared Index must only export LocalDataStore public constants/class')

const forbiddenBusinessFiles = [
  'entry/src/main/ets/entryability/EntryAbility.ets',
  'shared/src/main/ets/settings/DraftSettings.ets',
  'shared/src/main/ets/settings/SettingsBootstrap.ets',
  'shared/src/main/ets/settings/SettingsStorage.ets',
]
for (const rel of forbiddenBusinessFiles) {
  assert(!read(rel).includes('LocalDataStore'), `${rel} must not wire LocalDataStore outside migrated RDB settings`)
  assert(!read(rel).includes('V2Next.db'), `${rel} must not know RDB db name in this skeleton lane`)
}

const searchSettingsText = read('shared/src/main/ets/settings/SearchSettings.ets')
assert(searchSettingsText.includes("import { LocalDataStore } from '../storage/LocalDataStore'"), 'SearchSettings must be the only Lane 4 business settings LocalDataStore consumer')
assert(!searchSettingsText.includes('V2Next.db'), 'SearchSettings must not know RDB db name')
const collectionSettingsText = read('shared/src/main/ets/settings/CollectionSettings.ets')
assert(collectionSettingsText.includes("import { LocalDataStore } from '../storage/LocalDataStore'"), 'CollectionSettings must consume LocalDataStore for collection RDB')
assert(!collectionSettingsText.includes('V2Next.db'), 'CollectionSettings must not know RDB db name')

const sourceRoots = [
  'entry/src/main/ets',
  'feature/detail/src/main/ets',
  'feature/feed/src/main/ets',
  'feature/node/src/main/ets',
  'feature/settings/src/main/ets',
  'feature/user/src/main/ets',
  'shared/src/main/ets',
]
const walkTextFiles = (dir) => {
  const results = []
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      results.push(...walkTextFiles(full))
    } else if (/\.ets$/.test(entry.name)) {
      results.push(full)
    }
  }
  return results
}
for (const root of sourceRoots) {
  const absRoot = path.join(repo, root)
  if (!fs.existsSync(absRoot)) continue
  for (const abs of walkTextFiles(absRoot)) {
    const rel = path.relative(repo, abs)
    const text = fs.readFileSync(abs, 'utf8')
    if (
      rel === localDataRel ||
      rel === 'shared/src/main/ets/Index.ets' ||
      rel === 'shared/src/main/ets/settings/SearchSettings.ets' ||
      rel === 'shared/src/main/ets/settings/CollectionSettings.ets' ||
      rel === 'shared/src/main/ets/settings/UserMarkSettings.ets' ||
      rel === 'shared/src/main/ets/settings/CacheSettings.ets' ||
      rel === 'shared/src/main/ets/settings/CacheDeviceQaSeed.ets' ||
      rel === 'shared/src/main/ets/cache/TopicDetailActionOverlaySettings.ets' ||
      rel === 'shared/src/main/ets/storage/LocalDataCloudSync.ets'
    ) continue
    assert(!text.includes("@ohos.data.relationalStore") && !text.includes("'@kit.ArkData'") || !text.includes('relationalStore'), `${rel} must not add relationalStore usage outside LocalDataStore/SearchSettings Lane 4 boundary`)
  }
}

console.log('local data store contract OK')
