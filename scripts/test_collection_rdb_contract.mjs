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

const localData = read('shared/src/main/ets/storage/LocalDataStore.ets')
const collection = read('shared/src/main/ets/settings/CollectionSettings.ets')

const tableContracts = [
  {
    table: 'collection_saved_topics',
    primary: 'topic_id INTEGER PRIMARY KEY NOT NULL',
    index: 'CREATE INDEX IF NOT EXISTS idx_collection_saved_topics_saved_at ON collection_saved_topics (saved_at DESC, topic_id DESC)',
    order: 'ORDER BY saved_at DESC, topic_id DESC LIMIT 100',
    prune: 'DELETE FROM collection_saved_topics WHERE topic_id NOT IN (SELECT topic_id FROM collection_saved_topics ORDER BY saved_at DESC, topic_id DESC LIMIT 100)',
  },
  {
    table: 'collection_saved_nodes',
    primary: 'node_name TEXT PRIMARY KEY NOT NULL',
    index: 'CREATE INDEX IF NOT EXISTS idx_collection_saved_nodes_saved_at ON collection_saved_nodes (saved_at DESC, node_name ASC)',
    order: 'ORDER BY saved_at DESC, node_name ASC LIMIT 80',
    prune: 'DELETE FROM collection_saved_nodes WHERE node_name NOT IN (SELECT node_name FROM collection_saved_nodes ORDER BY saved_at DESC, node_name ASC LIMIT 80)',
  },
  {
    table: 'collection_viewed_topics',
    primary: 'topic_id INTEGER PRIMARY KEY NOT NULL',
    index: 'CREATE INDEX IF NOT EXISTS idx_collection_viewed_topics_viewed_at ON collection_viewed_topics (viewed_at DESC, topic_id DESC)',
    order: 'ORDER BY viewed_at DESC, topic_id DESC LIMIT 100',
    prune: 'DELETE FROM collection_viewed_topics WHERE topic_id NOT IN (SELECT topic_id FROM collection_viewed_topics ORDER BY viewed_at DESC, topic_id DESC LIMIT 100)',
  },
  {
    table: 'collection_topic_read_positions',
    primary: 'topic_id INTEGER PRIMARY KEY NOT NULL',
    index: 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_positions_updated_at ON collection_topic_read_positions (updated_at DESC, topic_id DESC)',
    order: 'ORDER BY updated_at DESC, topic_id DESC LIMIT 200',
    prune: 'DELETE FROM collection_topic_read_positions WHERE topic_id NOT IN (SELECT topic_id FROM collection_topic_read_positions ORDER BY updated_at DESC, topic_id DESC LIMIT 200)',
  },
  {
    table: 'collection_topic_read_states',
    primary: 'topic_id INTEGER PRIMARY KEY NOT NULL',
    index: 'CREATE INDEX IF NOT EXISTS idx_collection_topic_read_states_updated_at ON collection_topic_read_states (updated_at DESC, topic_id DESC)',
    order: 'ORDER BY updated_at DESC, topic_id DESC LIMIT 500',
    prune: 'DELETE FROM collection_topic_read_states WHERE topic_id NOT IN (SELECT topic_id FROM collection_topic_read_states ORDER BY updated_at DESC, topic_id DESC LIMIT 500)',
  },
]

assert(localData.includes('export const LOCAL_DATA_SCHEMA_VERSION: number = 6'), 'LocalDataStore schema version must be 6')
assert(localData.includes("VALUES (\\'schema_version\\', \\'6\\')"), 'schema_meta must store version 6')

for (const contract of tableContracts) {
  assert(localData.includes(`CREATE TABLE IF NOT EXISTS ${contract.table}`), `${contract.table} table must be created by LocalDataStore`)
  assert(localData.includes(contract.primary), `${contract.table} primary key contract missing`)
  assert(localData.includes(contract.index), `${contract.table} order index missing`)
  assert(collection.includes(contract.table), `${contract.table} must be used by CollectionSettings`)
  assert(collection.includes(contract.order), `${contract.table} read order/limit missing`)
  assert(collection.includes(contract.prune), `${contract.table} prune SQL missing`)
  assert(collection.includes(`DELETE FROM ${contract.table}`), `${contract.table} clear/delete SQL missing`)
}

for (const snippet of [
  'INSERT OR REPLACE INTO collection_saved_topics',
  'INSERT OR REPLACE INTO collection_saved_nodes',
  'INSERT OR REPLACE INTO collection_viewed_topics',
  'INSERT OR REPLACE INTO collection_topic_read_positions',
  'INSERT OR REPLACE INTO collection_topic_read_states',
  'SELECT COUNT(*) AS count_value FROM collection_saved_topics',
  'SELECT COUNT(*) AS count_value FROM collection_saved_nodes',
  'SELECT COUNT(*) AS count_value FROM collection_viewed_topics',
]) {
  assert(collection.includes(snippet), `CollectionSettings missing SQL operation: ${snippet}`)
}

for (const forbidden of [
  'preferences.getPreferences',
  '.getSync(KEY_SAVED_TOPICS',
  '.getSync(KEY_SAVED_NODES',
  '.getSync(KEY_VIEWED_TOPICS',
  '.getSync(KEY_TOPIC_READ_POSITIONS',
  '.getSync(KEY_TOPIC_READ_STATES',
  '.putSync(KEY_SAVED_TOPICS',
  '.putSync(KEY_SAVED_NODES',
  '.putSync(KEY_VIEWED_TOPICS',
  '.putSync(KEY_TOPIC_READ_POSITIONS',
  '.putSync(KEY_TOPIC_READ_STATES',
]) {
  assert(!collection.includes(forbidden), `clean break forbids Preferences primary read/write: ${forbidden}`)
}

assert(collection.includes('deleteLegacyCollectionKeysBestEffort'), 'legacy collection key deletion helper must remain')
assert(collection.includes('deleteKeysAndFlush(store, keys)'), 'legacy deletion must use best-effort SettingsStorage helper')
assert(collection.includes('withPreferencesStore<void>(context, STORE_NAME'), 'legacy deletion must target next2v_collections store')

const clearOrder = collection.indexOf('static async clearAll')
const clearDelete = collection.indexOf('await store.executeSql(SQL_CLEAR_TOPIC_READ_STATES)', clearOrder)
const clearLegacy = collection.indexOf('deleteLegacyCollectionKeysBestEffort', clearOrder)
assert(clearDelete >= 0 && clearLegacy > clearDelete, 'clearAll must delete legacy keys only after RDB clears')

assert(!localData.includes('CollectionSettings'), 'LocalDataStore must remain schema-only and not import business settings')
assert(!localData.includes('CollectionLimits'), 'LocalDataStore must not import business limits')
assert(!localData.includes('LocalDataPublisher'), 'LocalDataStore must not publish AppStorage')

console.log('collection RDB contract OK')
