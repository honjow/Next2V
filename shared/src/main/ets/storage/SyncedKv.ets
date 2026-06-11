import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'
import { CloudSyncScheduler } from './CloudSyncScheduler'

// Generic cloud-syncable key-value "catch-all" over the synced_kv table. Lets any feature persist a few
// scattered values that ride the device-cloud (端云协同) sync WITHOUT adding a new local table or a new
// AGC data type — only the one-time AGC `syncedKv` data type is needed. Use a dedicated structured table
// instead when the data is large, queried, or paginated (collections / history).
//
// kv_key is "<namespace>:<key>" so getAll(namespace) range-scans the primary-key index. Namespaces must
// not contain ':'; keys may. Values are caller-encoded strings (typically JSON). Cross-device conflicts
// resolve last-write-wins on updated_at.
const SQL_GET: string = 'SELECT value FROM synced_kv WHERE kv_key = ?'
const SQL_PUT: string =
  'INSERT INTO synced_kv (kv_key, value, updated_at) VALUES (?, ?, ?) ON CONFLICT(kv_key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at'
const SQL_DELETE: string = 'DELETE FROM synced_kv WHERE kv_key = ?'
const SQL_LIST_NAMESPACE: string =
  'SELECT kv_key, value FROM synced_kv WHERE kv_key >= ? AND kv_key < ? ORDER BY kv_key ASC'

export interface SyncedKvEntry {
  key: string
  value: string
}

export class SyncedKv {
  private static composeKey(namespace: string, key: string): string {
    return namespace + ':' + key
  }

  // Write/overwrite one value. Propagates storage errors so callers know a write failed.
  static async put(
    context: common.UIAbilityContext,
    namespace: string,
    key: string,
    value: string,
  ): Promise<void> {
    const store = await LocalDataStore.open(context)
    const args: relationalStore.ValueType[] = [
      SyncedKv.composeKey(namespace, key),
      value,
      Date.now(),
    ]
    await store.executeSql(SQL_PUT, args)
    CloudSyncScheduler.requestAfterLocalWrite(context, 'synced_kv')
  }

  // Read one value, or null if absent. Reads degrade to null on error so a missing flag never throws.
  static async get(
    context: common.UIAbilityContext,
    namespace: string,
    key: string,
  ): Promise<string | null> {
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [SyncedKv.composeKey(namespace, key)]
      const resultSet = await store.querySql(SQL_GET, args)
      try {
        if (!resultSet.goToFirstRow()) {
          return null
        }
        return resultSet.getString(resultSet.getColumnIndex('value'))
      } finally {
        resultSet.close()
      }
    } catch (error) {
      return null
    }
  }

  // All entries in a namespace, keyed by the bare item key (namespace prefix stripped). [] on error.
  static async getAll(
    context: common.UIAbilityContext,
    namespace: string,
  ): Promise<SyncedKvEntry[]> {
    const entries: SyncedKvEntry[] = []
    const prefix = namespace + ':'
    try {
      const store = await LocalDataStore.open(context)
      // Range scan [prefix, prefix + U+FFFF) over the PK index, cheaper and safer than a LIKE wildcard.
      const args: relationalStore.ValueType[] = [prefix, prefix + '￿']
      const resultSet = await store.querySql(SQL_LIST_NAMESPACE, args)
      try {
        const keyIndex = resultSet.getColumnIndex('kv_key')
        const valueIndex = resultSet.getColumnIndex('value')
        while (resultSet.goToNextRow()) {
          const fullKey = resultSet.getString(keyIndex)
          const entry: SyncedKvEntry = {
            key: fullKey.substring(prefix.length),
            value: resultSet.getString(valueIndex),
          }
          entries.push(entry)
        }
      } finally {
        resultSet.close()
      }
    } catch (error) {
      return entries
    }
    return entries
  }

  // Remove one value. Propagates storage errors.
  static async remove(
    context: common.UIAbilityContext,
    namespace: string,
    key: string,
  ): Promise<void> {
    const store = await LocalDataStore.open(context)
    const args: relationalStore.ValueType[] = [SyncedKv.composeKey(namespace, key)]
    await store.executeSql(SQL_DELETE, args)
    CloudSyncScheduler.requestAfterLocalWrite(context, 'synced_kv')
  }
}
