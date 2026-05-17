import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

export const LOCAL_DATA_DB_NAME: string = 'V2Next.db'
export const LOCAL_DATA_SCHEMA_VERSION: number = 2
export const LOCAL_DATA_SCHEMA_META_TABLE: string = 'schema_meta'

export const SQL_CREATE_SCHEMA_META_TABLE: string = 'CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)'
export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY NOT NULL, searched_at INTEGER NOT NULL)'
export const SQL_CREATE_SEARCH_HISTORY_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history (searched_at DESC)'
export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\'schema_version\', \'2\')'

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
    await store.execute(SQL_UPSERT_SCHEMA_VERSION)
    if (store.version !== LOCAL_DATA_SCHEMA_VERSION) {
      store.version = LOCAL_DATA_SCHEMA_VERSION
    }
    return store
  }
}
