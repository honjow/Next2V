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
  "export const LOCAL_DATA_DB_NAME: string = 'V2Next.db'",
  'export const LOCAL_DATA_SCHEMA_VERSION: number = 3',
  "export const LOCAL_DATA_SCHEMA_META_TABLE: string = 'schema_meta'",
  "export const SQL_CREATE_SCHEMA_META_TABLE: string = 'CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)'",
  "export const SQL_CREATE_SEARCH_HISTORY_TABLE: string = 'CREATE TABLE IF NOT EXISTS search_history (query TEXT PRIMARY KEY NOT NULL, searched_at INTEGER NOT NULL)'",
  "export const SQL_CREATE_SEARCH_HISTORY_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history (searched_at DESC)'",
  "export const SQL_CREATE_CACHE_ENTRIES_TABLE: string = 'CREATE TABLE IF NOT EXISTS cache_entries (cache_key TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, payload_text TEXT, payload_path TEXT, cached_at INTEGER NOT NULL, accessed_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, size INTEGER NOT NULL, etag TEXT, payload_hash TEXT)'",
  "export const SQL_CREATE_CACHE_ENTRIES_KIND_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_kind ON cache_entries (kind)'",
  "export const SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_expires_at ON cache_entries (expires_at)'",
  "export const SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX: string = 'CREATE INDEX IF NOT EXISTS idx_cache_entries_accessed_at ON cache_entries (accessed_at)'",
  "export const SQL_UPSERT_SCHEMA_VERSION: string = 'INSERT OR REPLACE INTO schema_meta (key, value) VALUES (\\'schema_version\\', \\'3\\')'",
  'securityLevel: relationalStore.SecurityLevel.S3',
  'relationalStore.getRdbStore(context, LOCAL_DATA_STORE_CONFIG)',
  'await store.execute(SQL_CREATE_SCHEMA_META_TABLE)',
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_TABLE)',
  'await store.execute(SQL_CREATE_SEARCH_HISTORY_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_TABLE)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_KIND_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_EXPIRES_AT_INDEX)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_ACCESSED_AT_INDEX)',
  'await store.execute(SQL_UPSERT_SCHEMA_VERSION)',
  'store.version = LOCAL_DATA_SCHEMA_VERSION',
  'return store',
]
for (const snippet of requiredSnippets) {
  assert(localDataText.includes(snippet), `LocalDataStore contract missing snippet: ${snippet}`)
}
assert(/export\s+class\s+LocalDataStore/.test(localDataText), 'LocalDataStore class must be exported')
assert(/static\s+async\s+open\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<\s*relationalStore\.RdbStore\s*>/.test(localDataText), 'LocalDataStore.open(context) signature missing')
assert(!localDataText.includes('CollectionSettings'), 'LocalDataStore skeleton must not wire collections')
assert(!localDataText.includes('DraftSettings'), 'LocalDataStore skeleton must not wire drafts')
assert(!localDataText.includes('SearchSettings'), 'LocalDataStore must not know SearchSettings')
assert(!localDataText.includes('CacheSettings'), 'LocalDataStore must not know CacheSettings')
assert(!localDataText.includes('BlockedMemberSettings'), 'LocalDataStore skeleton must not wire blocked members')

const indexText = read('shared/src/main/ets/Index.ets')
assert(indexText.includes("export { LocalDataStore, LOCAL_DATA_DB_NAME, LOCAL_DATA_SCHEMA_VERSION } from './storage/LocalDataStore'"), 'shared Index must only export LocalDataStore public constants/class')

const forbiddenBusinessFiles = [
  'entry/src/main/ets/entryability/EntryAbility.ets',
  'shared/src/main/ets/settings/CollectionSettings.ets',
  'shared/src/main/ets/settings/DraftSettings.ets',
  'shared/src/main/ets/settings/BlockedMemberSettings.ets',
  'shared/src/main/ets/settings/SettingsBootstrap.ets',
  'shared/src/main/ets/settings/SettingsStorage.ets',
]
for (const rel of forbiddenBusinessFiles) {
  assert(!read(rel).includes('LocalDataStore'), `${rel} must not wire LocalDataStore in this skeleton lane`)
  assert(!read(rel).includes('V2Next.db'), `${rel} must not know RDB db name in this skeleton lane`)
}

const searchSettingsText = read('shared/src/main/ets/settings/SearchSettings.ets')
assert(searchSettingsText.includes("import { LocalDataStore } from '../storage/LocalDataStore'"), 'SearchSettings must be the only Lane 4 business settings LocalDataStore consumer')
assert(!searchSettingsText.includes('V2Next.db'), 'SearchSettings must not know RDB db name')

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
      rel === 'shared/src/main/ets/settings/CacheSettings.ets'
    ) continue
    assert(!text.includes("@ohos.data.relationalStore") && !text.includes("'@kit.ArkData'") || !text.includes('relationalStore'), `${rel} must not add relationalStore usage outside LocalDataStore/SearchSettings Lane 4 boundary`)
  }
}

console.log('local data store contract OK')
