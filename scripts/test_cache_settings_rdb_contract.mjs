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
const cacheSettings = read('shared/src/main/ets/settings/CacheSettings.ets')

for (const snippet of [
  'export const LOCAL_DATA_SCHEMA_VERSION: number = 3',
  'CREATE TABLE IF NOT EXISTS cache_entries',
  'cache_key TEXT PRIMARY KEY NOT NULL',
  'kind TEXT NOT NULL',
  'payload_text TEXT',
  'payload_path TEXT',
  'cached_at INTEGER NOT NULL',
  'accessed_at INTEGER NOT NULL',
  'expires_at INTEGER NOT NULL',
  'size INTEGER NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_cache_entries_kind ON cache_entries (kind)',
  'CREATE INDEX IF NOT EXISTS idx_cache_entries_expires_at ON cache_entries (expires_at)',
  'CREATE INDEX IF NOT EXISTS idx_cache_entries_accessed_at ON cache_entries (accessed_at)',
  'await store.execute(SQL_CREATE_CACHE_ENTRIES_TABLE)',
]) {
  assert(localData.includes(snippet), `LocalDataStore missing cache schema contract: ${snippet}`)
}

for (const snippet of [
  "import { fileIo } from '@kit.CoreFileKit'",
  "import { LocalDataStore } from '../storage/LocalDataStore'",
  "const KEY_PREFIX_TOPIC_LIST: string = 'topicList:'",
  "const KEY_PREFIX_TOPIC_DETAIL: string = 'topicDetail:'",
  "const KEY_CACHE_INDEX: string = 'cacheIndex'",
  "const CACHE_KIND_TOPIC_LIST: string = 'topic_list'",
  "const CACHE_KIND_TOPIC_DETAIL: string = 'topic_detail'",
  "const CACHE_KINDS_SQL: string = `'${CACHE_KIND_TOPIC_LIST}', '${CACHE_KIND_TOPIC_DETAIL}'`",
  'const TOPIC_LIST_TTL_SECONDS: number = 7 * 24 * 60 * 60',
  'const TOPIC_DETAIL_TTL_SECONDS: number = 30 * 24 * 60 * 60',
  'const MAX_TOPIC_LIST_ROWS: number = 32',
  'const MAX_TOPIC_DETAIL_ROWS: number = 200',
  'const FILE_PAYLOAD_THRESHOLD_BYTES: number = 256 * 1024',
  'const MAX_CACHE_PAYLOAD_SIZE: number = 20 * 1024 * 1024',
  'const MAX_TOPIC_LIST_ITEMS: number = 50',
  'SELECT payload_text, payload_path, expires_at FROM cache_entries',
  'INSERT OR REPLACE INTO cache_entries',
  'payload_text, payload_path, cached_at',
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  'UPDATE cache_entries SET accessed_at = ?',
  'DELETE FROM cache_entries WHERE kind IN',
  'ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 32',
  'ORDER BY accessed_at DESC, cached_at DESC, cache_key ASC LIMIT 200',
  'ORDER BY accessed_at ASC, cached_at ASC, cache_key ASC LIMIT ?',
  'LocalDataStore.open(context)',
  'CacheSettings.byteLength(payloadText)',
  'context.filesDir + \'/\' + CACHE_PAYLOAD_DIR_NAME',
  'fileIo.mkdirSync(CacheSettings.payloadBaseDir(context), true)',
  'fileIo.openSync',
  'fileIo.writeSync',
  'fileIo.readTextSync',
  'fileIo.unlinkSync',
  'fileIo.listFileSync',
  'deleteRowsWithPayloadFiles',
  'deleteOrphanPayloadFiles',
  'isSafePayloadFileName',
  'deleteLegacyCacheBestEffort',
]) {
  assert(cacheSettings.includes(snippet), `CacheSettings missing RDB cache contract: ${snippet}`)
}

for (const nullableContract of [
  'payload_text TEXT, payload_path TEXT',
  'etag TEXT, payload_hash TEXT',
]) {
  assert(localData.includes(nullableContract), `cache_entries must keep nullable payload/hash columns: ${nullableContract}`)
}

for (const policyContract of [
  {
    name: 'expired cache rows are removed before index reads',
    pattern: /static\s+async\s+loadKeyIndex[\s\S]*await CacheSettings\.deleteExpiredRows\(context,\s*store,\s*now\)[\s\S]*store\.querySql\(SQL_SELECT_CACHE_INDEX\)/,
  },
  {
    name: 'expired cache rows are removed before stats reads',
    pattern: /static\s+async\s+loadStats[\s\S]*await CacheSettings\.deleteExpiredRows\(context,\s*store,\s*now\)[\s\S]*store\.querySql\(SQL_SELECT_CACHE_STATS\)/,
  },
  {
    name: 'expired cache rows are removed after writes before file-aware LRU pruning',
    pattern: /private\s+static\s+async\s+pruneCache[\s\S]*await CacheSettings\.deleteExpiredRows\(context,\s*store,\s*now\)[\s\S]*SQL_SELECT_PRUNE_TOPIC_LIST_PAYLOAD_PATHS[\s\S]*SQL_PRUNE_TOPIC_LIST_ROWS[\s\S]*SQL_SELECT_PRUNE_TOPIC_DETAIL_PAYLOAD_PATHS[\s\S]*SQL_PRUNE_TOPIC_DETAIL_ROWS[\s\S]*pruneCachePayloadSize/,
  },
  {
    name: 'topic list rows are trimmed before persistence',
    pattern: /const next = topics\.slice\(0,\s*MAX_TOPIC_LIST_ITEMS\)[\s\S]*JSON\.stringify\(next\)/,
  },
  {
    name: 'payload accounting uses UTF-8 byte size',
    pattern: /private\s+static\s+byteLength\s*\([\s\S]*charCodeAt[\s\S]*0xD800[\s\S]*0xDFFF[\s\S]*return bytes/,
  },
  {
    name: 'file-backed save stores null inline text and relative payload path',
    pattern: /private\s+static\s+preparePayloadStorage[\s\S]*size\s*<\s*FILE_PAYLOAD_THRESHOLD_BYTES[\s\S]*payloadText:\s*payloadText[\s\S]*payloadPath:\s*null[\s\S]*payloadText:\s*null[\s\S]*payloadPath:\s*payloadFileName/,
  },
  {
    name: 'load prefers safe readable file and falls back to inline payload text',
    pattern: /private\s+static\s+resolvePayloadText[\s\S]*isSafePayloadFileName\(payloadPath\)[\s\S]*fileIo\.readTextSync[\s\S]*return payloadText/,
  },
  {
    name: 'clear removes cache rows through payload cleanup and keeps legacy cleanup',
    pattern: /static\s+async\s+clear[\s\S]*deleteRowsWithPayloadFiles[\s\S]*SQL_SELECT_CLEAR_CACHE_PAYLOAD_PATHS[\s\S]*SQL_CLEAR_CACHE_ENTRIES[\s\S]*deleteOrphanPayloadFiles[\s\S]*deleteLegacyCacheBestEffort/,
  },
  {
    name: 'payload filename guard rejects slash, backslash, traversal, empty and leading dot names',
    pattern: /private\s+static\s+isSafePayloadFileName[\s\S]*relativeName\.length\s*<=\s*0[\s\S]*relativeName\.startsWith\('\.'\)[\s\S]*relativeName\.includes\('\/'\)[\s\S]*relativeName\.includes\('\\\\'\)[\s\S]*relativeName\.includes\('\.\.'\)[\s\S]*\^\[A-Za-z0-9\._-\]\+/,
  },
]) {
  assert(policyContract.pattern.test(cacheSettings), `CacheSettings policy contract missing: ${policyContract.name}`)
}

for (const sqlName of [
  'SQL_SELECT_CACHE_INDEX',
  'SQL_SELECT_CACHE_STATS',
  'SQL_SELECT_EXPIRED_CACHE_PAYLOAD_PATHS',
  'SQL_DELETE_EXPIRED_CACHE_ENTRIES',
  'SQL_SELECT_CLEAR_CACHE_PAYLOAD_PATHS',
  'SQL_CLEAR_CACHE_ENTRIES',
  'SQL_SELECT_CACHE_PAYLOAD_SIZE',
  'SQL_SELECT_PRUNE_CACHE_PAYLOAD_PATHS',
  'SQL_PRUNE_CACHE_PAYLOAD_SIZE',
  'SQL_SELECT_ACTIVE_CACHE_PAYLOAD_PATHS',
]) {
  const pattern = new RegExp(`const\\s+${sqlName}:\\s+string\\s+=\\s+\`[^\`]*\\$\\{CACHE_KINDS_SQL\\}`)
  assert(pattern.test(cacheSettings), `${sqlName} must use the centralized cache kind set`)
}

for (const rawDelete of [
  'await store.executeSql(SQL_DELETE_EXPIRED_CACHE_ENTRIES',
  'await store.executeSql(SQL_PRUNE_TOPIC_LIST_ROWS',
  'await store.executeSql(SQL_PRUNE_TOPIC_DETAIL_ROWS',
  'await store.executeSql(SQL_PRUNE_CACHE_PAYLOAD_SIZE',
  'await store.executeSql(SQL_CLEAR_CACHE_ENTRIES',
]) {
  assert(!cacheSettings.includes(rawDelete), `CacheSettings must not bypass payload cleanup: ${rawDelete}`)
}

assert(!cacheSettings.includes('import { preferences }'), 'CacheSettings must not import preferences for primary cache read/write')
assert(!cacheSettings.includes('preferences.getPreferences'), 'CacheSettings must not call preferences.getPreferences directly')

for (const signature of [
  /export\s+interface\s+TopicDetailCache\s*{[\s\S]*topic\s*:\s*V2exTopic\s*\|\s*null[\s\S]*replies\s*:\s*V2exReply\[\][\s\S]*cachedAt\s*:\s*number[\s\S]*}/,
  /export\s+interface\s+CacheStats\s*{[\s\S]*topicListCount\s*:\s*number[\s\S]*topicDetailCount\s*:\s*number[\s\S]*updatedAt\s*:\s*number[\s\S]*}/,
  /export\s+interface\s+CacheKeyIndex\s*{[\s\S]*topicLists\s*:\s*string\[\][\s\S]*topicDetails\s*:\s*number\[\][\s\S]*updatedAt\s*:\s*number[\s\S]*}/,
  /static\s+async\s+loadKeyIndex\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<\s*CacheKeyIndex\s*>/,
  /static\s+async\s+loadTopicList\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*,\s*cacheKey\s*:\s*string\s*\)\s*:\s*Promise<\s*V2exTopic\[\]\s*>/,
  /static\s+async\s+saveTopicList\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*,\s*cacheKey\s*:\s*string\s*,\s*topics\s*:\s*V2exTopic\[\]\s*\)\s*:\s*Promise<\s*void\s*>/,
  /static\s+async\s+loadTopicDetail\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*,\s*topicId\s*:\s*number\s*\)\s*:\s*Promise<\s*TopicDetailCache\s*\|\s*null\s*>/,
  /static\s+async\s+saveTopicDetail\s*\([\s\S]*context\s*:\s*common\.UIAbilityContext[\s\S]*topicId\s*:\s*number[\s\S]*topic\s*:\s*V2exTopic\s*\|\s*null[\s\S]*replies\s*:\s*V2exReply\[\][\s\S]*\)\s*:\s*Promise<\s*void\s*>/,
  /static\s+async\s+loadStats\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<\s*CacheStats\s*>/,
  /static\s+async\s+clear\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<\s*void\s*>/,
]) {
  assert(signature.test(cacheSettings), `CacheSettings public API changed or missing: ${signature}`)
}

const sourceRoots = [
  'entry/src/main/ets',
  'feature/detail/src/main/ets',
  'feature/feed/src/main/ets',
  'feature/node/src/main/ets',
  'feature/settings/src/main/ets',
  'feature/user/src/main/ets',
  'shared/src/main/ets',
]
const allowedRelationalStoreUsers = new Set([
  'shared/src/main/ets/storage/LocalDataStore.ets',
  'shared/src/main/ets/settings/SearchSettings.ets',
  'shared/src/main/ets/settings/CacheSettings.ets',
])
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
    if (allowedRelationalStoreUsers.has(rel)) continue
    assert(!text.includes('relationalStore'), `${rel} must not import/use relationalStore directly for cache`)
  }
}

console.log('cache settings RDB contract OK')
