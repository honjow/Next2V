#!/usr/bin/env node
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

// The coin balance row (AccountCoinBalance + its AccountCoinIcon) lives in the shared dashboard
// components, used by both the Me card and the account detail header — not in AccountPage directly.
const componentsPath = 'entry/src/main/ets/components/AccountDashboardComponents.ets'
const coinIconPath = 'entry/src/main/ets/components/AccountCoinIcon.ets'
const dashboardComponents = read(componentsPath)

assert.doesNotMatch(dashboardComponents, /struct\s+AccountCoinIconCanvas\b/)
assert.match(dashboardComponents, /import\s+\{\s*AccountCoinIcon\s*\}\s+from\s+'\.\/AccountCoinIcon'/)
assert.match(dashboardComponents, /AccountCoinIcon\(\{\s*rimColor,\s*faceColor,\s*edgeColor\s*\}\)/)

assert.ok(existsSync(coinIconPath), 'AccountCoinIcon component file must exist')
const coinIcon = read(coinIconPath)
assert.match(coinIcon, /export\s+struct\s+AccountCoinIcon\b/)

for (const marker of [
  'arc(8, 8, 7.2',
  'arc(8, 8, 5.8',
  'arc(8, 8, 6.9',
  'lineWidth = 1.2',
  'strokeStyle = this.rimColor',
]) {
  assert.ok(coinIcon.includes(marker), `old rimmed drawing marker missing: ${marker}`)
}

assert.ok(!coinIcon.includes('arc(8, 8, 3.1'), 'central coin circle must not be restored')

const changed = execFileSync('git', ['diff', '--name-only'], { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean)

for (const file of changed) {
  assert.ok(
    !/parser|network|storage|rdb|settings|mission|auth|saved/i.test(file),
    `account balance parser/network/storage-adjacent file must not be edited: ${file}`,
  )
}

console.log('PASS account coin icon static contract')
