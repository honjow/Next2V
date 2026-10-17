#!/usr/bin/env node
// Exercise the real release gate in an isolated fixture; never mutate working-tree metadata.
import assert from 'node:assert/strict'
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const fixture = mkdtempSync(join(tmpdir(), 'next2v-release-notes-'))
const appPath = 'AppScope/app.json5'
const app = readFileSync(join(root, appPath), 'utf8')
const version = app.match(/"versionName"\s*:\s*"([^"]+)"/)[1]
const notesPath = join(fixture, `changelog/v${version}.md`)
const paths = [appPath, 'oh-package.json5', 'entry/oh-package.json5',
  'feature/settings/src/main/ets/pages/StorageSettingsPage.ets',
  'shared/src/main/ets/backup/BackupService.ets']
for (const module of ['shared', ...['detail', 'feed', 'node', 'settings', 'user'].map(name => `feature/${name}`)]) {
  paths.push(`${module}/oh-package.json5`, `${module}/BuildProfile.ets`)
}

function check(ref, expectedFailure = '') {
  const result = spawnSync(process.execPath, [join(root, 'scripts/test_version_consistency_contract.mjs')], {
    cwd: fixture, env: { ...process.env, GITHUB_REF: ref }, encoding: 'utf8', timeout: 10000,
  })
  assert.ifError(result.error)
  const output = result.stdout + result.stderr
  assert.equal(result.status, expectedFailure ? 1 : 0, output)
  if (expectedFailure) assert.ok(output.includes(expectedFailure), output)
}

try {
  for (const path of paths) {
    const target = join(fixture, path)
    mkdirSync(dirname(target), { recursive: true })
    copyFileSync(join(root, path), target)
  }
  mkdirSync(dirname(notesPath), { recursive: true })
  writeFileSync(notesPath, '## 修复\n\n- 合成测试日志。\n')
  check('')
  check('refs/heads/master')
  check('refs/pull/1/merge')
  check(`refs/tags/v${version}`)
  check(`refs/tags/v${version}-wrong`, 'release tag')
  check(`refs/tags/${version}`, 'release tag')
  rmSync(notesPath)
  check(`refs/tags/v${version}`, 'must exist and be non-empty')
  writeFileSync(notesPath, ' \n\t')
  check('refs/heads/master', 'must exist and be non-empty')
  writeFileSync(notesPath, '## 修复\n\n- 合成测试日志。\n')
  writeFileSync(join(fixture, 'entry/oh-package.json5'), '{"version":"0.0.0"}')
  check(`refs/tags/v${version}`, 'entry/oh-package.json5')
  console.log('release notes contract passed (9 isolated release-gate scenarios)')
} finally {
  rmSync(fixture, { recursive: true, force: true })
}
