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

const seed = read('shared/src/main/ets/settings/CacheDeviceQaSeed.ets')
const policy = read('shared/src/main/ets/settings/CachePolicy.ets')
const storage = read('feature/settings/src/main/ets/pages/StorageSettingsPage.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')

assert(seed.includes("import BuildProfile from '../../../../BuildProfile'"), 'seed utility must import shared BuildProfile')
assert(/static\s+isEnabled\s*\(\s*\)\s*:\s*boolean\s*{[\s\S]*return\s+BuildProfile\.DEBUG[\s\S]*}/.test(seed), 'seed utility must expose BuildProfile.DEBUG isEnabled guard')
assert(seed.includes('static assertEnabled(): void') && seed.includes('CacheDeviceQaSeed.isEnabled()'), 'seed utility must expose assertEnabled guard')

for (const method of [
  'seedLargeFileBackedList',
  'seedMixedInlineFile',
  'seedInvalidPathRow',
  'seedOrphanPayloadFile',
  'seedMissingFileRow',
  'seedHashMismatchRow',
  'validateHashMismatchRepair',
  'seedExpiredRow',
  'resetSeededCache',
  'seedAll',
]) {
  const pattern = new RegExp(`static\\s+async\\s+${method}[\\s\\S]*?CacheDeviceQaSeed\\.assertEnabled\\(\\)`)
  assert(pattern.test(seed), `${method} must call assertEnabled internally`)
}

for (const scenario of [
  'large_file_backed',
  'mixed_inline_file',
  'invalid_path',
  'orphan_file',
  'missing_file',
  'hash_mismatch',
  'hash_mismatch_validate',
  'expired_row',
  'reset_seeded',
]) {
  assert(seed.includes(`'${scenario}'`), `missing seed scenario ${scenario}`)
}

assert(seed.includes("await CacheSettings.saveTopicList(context, 'qa-seed-large-list'"), 'large list seed must use CacheSettings.saveTopicList')
assert(seed.includes("await CacheSettings.saveTopicList(context, 'qa-seed-mixed-inline'"), 'mixed inline list seed must use CacheSettings.saveTopicList')
assert(seed.includes('await CacheSettings.saveTopicDetail('), 'mixed detail seed must use CacheSettings.saveTopicDetail')
assert(seed.includes("'../outside-cache.json'"), 'invalid path DB fixture missing')
assert(seed.includes("const WRONG_PAYLOAD_HASH: string = 'v1:fnv1a32-utf8:1:00000000'"), 'hash mismatch seed must use intentionally wrong versioned hash fixture')
assert(seed.includes("SEED_TOPIC_LIST_FILE_PREFIX + 'hash_mismatch' + CACHE_PAYLOAD_FILE_SUFFIX"), 'hash mismatch seed must use a safe seed payload filename')
assert(seed.includes("await CacheSettings.loadTopicList(context, 'qa-seed-hash-mismatch')"), 'hash mismatch validation must call production CacheSettings.loadTopicList')
assert(!/payloadFilePath\s*\(\s*context\s*,\s*['"]\.\.\//.test(seed), 'invalid traversal value must never be passed to fileIo path helpers')
assert(seed.includes("const SQL_DELETE_SEEDED_CACHE_ROWS: string = 'DELETE FROM cache_entries WHERE cache_key LIKE ? OR cache_key IN (?, ?, ?)'"), 'reset must target seed row predicates only')
assert(seed.includes("SEED_LIST_KEY_PREFIX + '%'"), 'reset must use seed list prefix')
assert(seed.includes("import {\n  CACHE_KIND_TOPIC_DETAIL") || seed.includes("from './CachePolicy'"), 'seed utility must import shared cache policy constants')
assert(policy.includes("export const KEY_PREFIX_TOPIC_LIST: string = 'topicList:'"), 'shared policy must preserve topic list prefix')
assert(policy.includes("export const KEY_PREFIX_TOPIC_DETAIL: string = 'topicDetail:'"), 'shared policy must preserve topic detail prefix')
assert(policy.includes("export const CACHE_KIND_TOPIC_LIST: string = 'topic_list'"), 'shared policy must preserve topic list kind')
assert(policy.includes("export const CACHE_KIND_TOPIC_DETAIL: string = 'topic_detail'"), 'shared policy must preserve topic detail kind')
assert(seed.includes('isSafeSeedPayloadFileName') && seed.includes('isProductionSeedPayloadFileName'), 'reset must restrict deleted payload files to seed-created names')
assert(!seed.includes('ApiService') && !seed.includes('HttpClient') && !seed.includes('V2exNativeAuthService'), 'seed utility must not import network/auth clients')

assert(storage.includes("import BuildProfile from '../../../../BuildProfile'"), 'storage seed UI must import feature BuildProfile')
assert(/if\s*\(\s*BuildProfile\.DEBUG\s*&&\s*CacheDeviceQaSeed\.isEnabled\(\)\s*\)/.test(storage), 'storage seed section must be BuildProfile.DEBUG guarded')
assert(/!BuildProfile\.DEBUG\s*\|\|\s*!CacheDeviceQaSeed\.isEnabled\(\)/.test(storage), 'storage seed actions must runtime-check debug guard')
assert(storage.includes('Seed 全部缓存场景') && storage.includes('重置 Seed 缓存'), 'storage seed UI rows missing')
assert(storage.includes('Seed Hash 不匹配行') && storage.includes('验证 Hash 修复'), 'storage hash mismatch seed/validation UI rows missing')
assert(storage.includes('CacheDeviceQaSeed.seedHashMismatchRow') && storage.includes('CacheDeviceQaSeed.validateHashMismatchRepair'), 'storage hash mismatch actions missing')
assert(sharedIndex.includes("export { CacheDeviceQaSeed } from './settings/CacheDeviceQaSeed'"), 'shared index must export CacheDeviceQaSeed')

console.log('cache device QA seed static contract OK')
