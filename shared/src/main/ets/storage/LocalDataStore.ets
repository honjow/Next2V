import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

export const LOCAL_DATA_DB_NAME: string = 'V2Next.db'
export const LOCAL_DATA_SCHEMA_VERSION: number = 4
export const LOCAL_DATA_SCHEMA_META_TABLE: string = 'schema_meta'

export const SQL_CREATE_SCHEMA_META_TABLE: string = 'CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)'
export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY NOT NULL, searched_at INTEGER NOT NULL)'
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
export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\'schema_version\', \'4\')'

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
    await store.execute(SQL_UPSERT_SCHEMA_VERSION)
    if (store.version !== LOCAL_DATA_SCHEMA_VERSION) {
      store.version = LOCAL_DATA_SCHEMA_VERSION
    }
    return store
  }
}
