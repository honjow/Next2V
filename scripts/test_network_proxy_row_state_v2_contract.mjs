#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const pagePath = 'feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets'
const page = readFileSync(new URL(`../${pagePath}`, import.meta.url), 'utf8')

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(text, needle, message) {
  if (!text.includes(needle)) {
    fail(message || `missing expected text: ${needle}`)
  }
}

function assertNotIncludes(text, needle, message) {
  if (text.includes(needle)) {
    fail(message || `forbidden text found: ${needle}`)
  }
}

function methodBody(text, methodName) {
  const marker = methodName.includes('(') ? methodName : `${methodName}(`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
  }
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') depth += 1
    if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  fail(`unterminated method body for: ${marker}`)
}

// Row model must be a State Management V2 observed class, not a plain interface,
// so editing a same-id profile refreshes its row in place.
assertIncludes(page, '@ObservedV2', 'proxy profile row model must use State Management V2 @ObservedV2')
assertIncludes(page, 'class NetworkProxyProfileRow', 'proxy profile row model must be a class, not a plain interface')
assertNotIncludes(page, 'interface NetworkProxyProfileRow', 'proxy profile row model must not be a plain interface')

for (const field of ['name', 'snapshot']) {
  const pattern = new RegExp(`@Trace\\s+${field}\\s*:`)
  if (!pattern.test(page)) {
    fail(`NetworkProxyProfileRow.${field} must be @Trace so same-id profile edits refresh the row`)
  }
}

// V2 component boundary subscribes the row to @Trace updates; selection/enabled
// are page state passed down as @Param; select/edit/apply are @Event callbacks.
assertIncludes(page, '@ComponentV2', 'proxy profile row view must use a V2 component boundary')
assertIncludes(page, '@Param row: NetworkProxyProfileRow', 'V2 row view must receive the observed row model via @Param')
assertIncludes(page, '@Param selected', 'selection state must reach the row as @Param (page state, not row state)')
for (const ev of ['@Event onSelect', '@Event onEdit', '@Event onApply']) {
  assertIncludes(page, ev, `V2 row view must surface ${ev} as a callback, not read parent state directly`)
}

// Stable row identity store (mirrors blocked-member / saved-node patterns).
assertIncludes(page, 'private profileRowsById: Map<string, NetworkProxyProfileRow>', 'page must keep stable row objects by profile id')
assertIncludes(page, 'private ensureProfileRowsForIds', 'page must expose an id-diff helper that reuses row objects')
assertIncludes(page, 'private profileRowForId', 'page must create/reuse exactly one row object per profile id')
assertIncludes(page, '.applyProfile(', 'profile updates must mutate the existing row object in place')

// Selection must stay page state, computed and passed down (not moved into the row).
assertIncludes(page, 'private isProfileSelected', 'selection must be computed from page mode/active state')

// ForEach must render the canonical row store and key on identity only.
const sectionBody = methodBody(page, '  ProxyConnectionSection')
assertIncludes(sectionBody, 'ForEach(this.profiles, (row: NetworkProxyProfileRow)', 'profile list must render the canonical V2 row store')
assertIncludes(sectionBody, '`proxy-profile-${row.id}`', 'proxy profile row key must be a pure identity key')
assertIncludes(sectionBody, 'NetworkProxyProfileRowView({', 'profile rows must render through the V2 row view')
assertIncludes(sectionBody, 'selected: this.isProfileSelected(', 'row selection must be passed from page state via @Param')

// The previous implementation churned the key on updatedAt to force same-id
// edited rows to rebuild. Guard against any churn token returning in a key.
const codeOnly = page.replace(/\/\/.*$/gm, '')
assertNotIncludes(codeOnly, 'updatedAt', 'proxy row code must not use updatedAt (key churn / clone leftover); explanatory comments may mention it')
assertNotIncludes(sectionBody, 'Date.now()', 'proxy profile key must not use Date.now churn')
for (const churn of ['-${profile.updatedAt}', '${profile.id}-', '-${row.updatedAt}']) {
  assertNotIncludes(sectionBody, churn, `ForEach key must not append churn token ${churn}`)
}

// Data must flow through applyProfiles (reuse + @Trace update), never by
// cloning into a fresh plain NetworkProxyProfile[] array.
assertNotIncludes(page, 'cloneProfiles', 'cloneProfiles plain-object rebuild must be replaced by in-place row apply')
const applyStateBody = methodBody(page, 'private applyProfilesState')
assertIncludes(applyStateBody, 'this.applyProfiles(', 'applyProfilesState must route through the stable row store')
assertNotIncludes(applyStateBody, 'this.cloneProfiles', 'applyProfilesState must not rebuild rows as plain clones')

console.log('PASS: network proxy row state V2 contract')
