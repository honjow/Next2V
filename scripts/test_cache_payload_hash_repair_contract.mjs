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

const cacheSettings = read('shared/src/main/ets/settings/CacheSettings.ets')
const seed = read('shared/src/main/ets/settings/CacheDeviceQaSeed.ets')

assert(
  cacheSettings.includes('SELECT payload_text, payload_path, payload_hash, expires_at FROM cache_entries'),
  'cache reads must select payload_hash with payload columns'
)
assert(
  cacheSettings.includes('payload_text, payload_path, payload_hash, cached_at, accessed_at, expires_at, size') &&
    cacheSettings.includes('VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'),
  'cache upsert must store payload_hash with nine placeholders'
)
assert(
  /const payloadHash = CacheSettings\.payloadHash\(payloadText\)[\s\S]*payloadPlan\.payloadPath,[\s\S]*payloadHash,[\s\S]*cachedAt/.test(cacheSettings),
  'saveCacheEntry must compute payloadHash(payloadText) and include it in SQL args'
)
assert(
  /const resolvedPayload = CacheSettings\.resolvePayloadText\(context,\s*payloadText,\s*payloadPath\)[\s\S]*if\s*\(resolvedPayload\.length <= 0\)[\s\S]*if\s*\(payloadHash\.length > 0 && CacheSettings\.payloadHash\(resolvedPayload\) !== payloadHash\)[\s\S]*await CacheSettings\.deleteCacheEntry\(context,\s*store,\s*cacheKey,\s*kind\)[\s\S]*return null/.test(cacheSettings),
  'read path must verify non-empty payload_hash after resolution and delete only the affected cache entry on mismatch'
)
assert(
  /if\s*\(payloadHash\.length > 0 && CacheSettings\.payloadHash\(resolvedPayload\) !== payloadHash\)/.test(cacheSettings),
  'null or empty payload_hash must stay legacy-compatible'
)
assert(
  /private\s+static\s+payloadHash\(payloadText: string\): string[\s\S]*return 'v1:fnv1a32-utf8:' \+ bytes\.toString\(\) \+ ':' \+ hash\.toString\(16\)\.padStart\(8,\s*'0'\)/.test(cacheSettings),
  'payloadHash must use the versioned v1:fnv1a32-utf8:<bytes>:<hex8> format'
)
assert(
  cacheSettings.includes('Math.imul((hash ^ (byte & 0xFF)) >>> 0, 16777619) >>> 0'),
  'payloadHash must use Math.imul FNV-1a multiplication'
)
assert(
  /private\s+static\s+resolvePayloadText[\s\S]*payloadPath\.length > 0 && CacheSettings\.isCachePayloadFileName\(payloadPath\)[\s\S]*fileIo\.readTextSync[\s\S]*return payloadText/.test(cacheSettings),
  'unsafe payload_path values must not be passed to fileIo and must retain inline fallback'
)

assert(seed.includes("'hash_mismatch'"), 'seed utility must expose hash_mismatch scenario')
assert(seed.includes("const WRONG_PAYLOAD_HASH: string = 'v1:fnv1a32-utf8:1:00000000'"), 'hash mismatch fixture must be intentionally wrong')
assert(seed.includes("await CacheSettings.loadTopicList(context, 'qa-seed-hash-mismatch')"), 'validation action must call the production cache read path')
assert(/static\s+async\s+seedAll[\s\S]*seedMissingFileRow[\s\S]*seedHashMismatchRow[\s\S]*seedExpiredRow/.test(seed), 'seedAll must include hash mismatch scenario')
assert(/static\s+async\s+validateHashMismatchRepair[\s\S]*CacheDeviceQaSeed\.assertEnabled\(\)/.test(seed), 'hash mismatch validation must be debug guarded')
assert(!seed.includes('ApiService') && !seed.includes('HttpClient') && !seed.includes('V2exNativeAuthService'), 'hash mismatch seed must not depend on network/auth clients')

console.log('cache payload hash repair contract OK')
