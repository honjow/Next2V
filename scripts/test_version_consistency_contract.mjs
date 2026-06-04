#!/usr/bin/env node
/**
 * Version consistency: every version string must match AppScope/app.json5.
 *
 * The app version is duplicated across many files (root + per-module oh-package.json5, generated
 * BuildProfile.ets HAR_VERSION, and a couple of hardcoded fallbacks). A release that bumps only
 * app.json5 leaves stale versions behind (the 1.0.0 release shipped with the entry module still at
 * 0.9.1, which showed up in crash stacks). This contract makes AppScope/app.json5 the single source of
 * truth and fails when anything drifts from it.
 *
 * Run: node scripts/test_version_consistency_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (p) => readFileSync(p, 'utf8')
const app = read('AppScope/app.json5')
const versionName = (app.match(/"versionName"\s*:\s*"([^"]+)"/) || [])[1]
const versionCode = Number((app.match(/"versionCode"\s*:\s*(\d+)/) || [])[1])
assert.ok(versionName, 'AppScope/app.json5 must declare versionName')
assert.ok(Number.isFinite(versionCode), 'AppScope/app.json5 must declare versionCode')

const failures = []
const expectName = (file, actual) => {
  if (actual !== versionName) failures.push(`${file}: "${actual}" !== app versionName "${versionName}"`)
}

// root + per-module oh-package.json5 "version" (first occurrence = the package's own version)
const pkgFiles = [
  'oh-package.json5',
  'entry/oh-package.json5',
  'shared/oh-package.json5',
  'feature/detail/oh-package.json5',
  'feature/feed/oh-package.json5',
  'feature/node/oh-package.json5',
  'feature/settings/oh-package.json5',
  'feature/user/oh-package.json5',
]
for (const f of pkgFiles) {
  expectName(f, (read(f).match(/"version"\s*:\s*"([^"]+)"/) || [])[1])
}

// generated BuildProfile.ets HAR_VERSION
const harFiles = [
  'feature/detail/BuildProfile.ets',
  'feature/feed/BuildProfile.ets',
  'feature/node/BuildProfile.ets',
  'feature/settings/BuildProfile.ets',
  'feature/user/BuildProfile.ets',
  'shared/BuildProfile.ets',
]
for (const f of harFiles) {
  expectName(f, (read(f).match(/HAR_VERSION\s*=\s*'([^']+)'/) || [])[1])
}

// hardcoded app-version fallbacks (backup metadata)
const sp = read('feature/settings/src/main/ets/pages/StorageSettingsPage.ets')
expectName('StorageSettingsPage.ets', (sp.match(/versionName:\s*'([^']+)'/) || [])[1])
{
  const code = Number((sp.match(/versionName:\s*'[^']+',\s*versionCode:\s*(\d+)/) || [])[1])
  if (code !== versionCode) failures.push(`StorageSettingsPage.ets: versionCode ${code} !== ${versionCode}`)
}
const bs = read('shared/src/main/ets/backup/BackupService.ets')
expectName('BackupService.ets', (bs.match(/versionName\s*\|\|\s*'([^']+)'/) || [])[1])
{
  const code = Number((bs.match(/versionCode\s*\|\|\s*(\d+)/) || [])[1])
  if (code !== versionCode) failures.push(`BackupService.ets: versionCode ${code} !== ${versionCode}`)
}

assert.deepEqual(failures, [], `version drift from app.json5 (${versionName} / ${versionCode}):\n  ${failures.join('\n  ')}`)
console.log(`version consistency contract passed (${versionName} / ${versionCode})`)
