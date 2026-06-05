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
const searchSettings = read('shared/src/main/ets/settings/SearchSettings.ets')

const requiredLocalDataSnippets = [
  'export const LOCAL_DATA_SCHEMA_VERSION: number = 7',
  "export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY, searched_at INTEGER)'",
  "export const SQL_CREATE_SEARCH_HISTORY_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history (searched_at DESC)'",
  "export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\\'schema_version\\', \\'7\\')'",
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_TABLE)',
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_INDEX)',
]
for (const snippet of requiredLocalDataSnippets) {
  assert(localData.includes(snippet), `LocalDataStore missing search-history RDB contract: ${snippet}`)
}

const requiredSearchSnippets = [
  "import { relationalStore } from '@kit.ArkData'",
  "import { LocalDataStore } from '../storage/LocalDataStore'",
  "const SQL_SELECT_HISTORY: string = 'SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 20'",
  "const SQL_UPSERT_HISTORY: string = 'INSERT OR REPLACE INTO search_history (query, searched_at) VALUES (?, ?)'",
  "const SQL_PRUNE_HISTORY: string = 'DELETE FROM search_history WHERE query NOT IN (SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 20)'",
  "const SQL_CLEAR_HISTORY: string = 'DELETE FROM search_history'",
  'LocalDataStore.open(context)',
  'await store.querySql(SQL_SELECT_HISTORY)',
  'await store.executeSql(SQL_UPSERT_HISTORY',
  'await store.executeSql(SQL_PRUNE_HISTORY)',
  'await store.executeSql(SQL_CLEAR_HISTORY)',
]
for (const snippet of requiredSearchSnippets) {
  assert(searchSettings.includes(snippet), `SearchSettings missing search-history RDB contract: ${snippet}`)
}

assert(!searchSettings.includes('writeJsonValue<string[]>(store, KEY_HISTORY'), 'SearchSettings must not write searchHistory to Preferences')
assert(searchSettings.includes('deleteLegacyHistoryBestEffort'), 'SearchSettings should keep clean-break legacy Preferences deletion best-effort and non-migrating')
assert(searchSettings.includes("const KEY_HISTORY: string = 'searchHistory'"), 'SearchSettings must keep legacy searchHistory key constant for contract/clean-break traceability')
assert(searchSettings.includes("const KEY_SOURCE_MODE: string = 'sourceMode'"), 'SearchSettings must keep sourceMode Preferences key')
assert(searchSettings.includes('withPreferencesStore<SearchSourceMode>'), 'SearchSettings must keep sourceMode on Preferences for Lane 4')

console.log('search history RDB contract OK')
