#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const pagePath = 'entry/src/main/ets/pages/SavedNodesPage.ets'
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
// so async icon/title enrichment can refresh a same-name row in place.
assertIncludes(page, '@ObservedV2', 'saved node row model must use State Management V2 @ObservedV2')
assertIncludes(page, 'class SavedNodeRow', 'saved node row model must be a class, not a plain interface')
assertNotIncludes(page, 'interface SavedNodeRow', 'saved node row model must not be a plain interface')

for (const field of ['title', 'topics', 'icon', 'savedAt']) {
  const pattern = new RegExp(`@Trace\\s+${field}\\s*:`)
  if (!pattern.test(page)) {
    fail(`SavedNodeRow.${field} must be @Trace so same-name row content updates refresh UI`)
  }
}

// V2 component boundary is what subscribes the row to @Trace field updates.
assertIncludes(page, '@ComponentV2', 'saved node row view must use a V2 component boundary')
assertIncludes(page, '@Param row: SavedNodeRow', 'V2 row view must receive the observed row model via @Param')
assertIncludes(page, '@Event onOpen', 'V2 row view must surface open action via @Event, not a parent-state read')
assertNotIncludes(page, 'trailingText: this.rowSavedDate()', 'saved node row must not show saved date as trailing text')
assertNotIncludes(page, 'private rowSavedDate()', 'saved node row must not carry a saved-date formatter')
assertNotIncludes(page, 'DateUtils', 'saved node row must not import date formatting just to show saved time')

const rowSubtitleBody = methodBody(page, 'private rowSubtitle')
assertNotIncludes(
  rowSubtitleBody,
  'saved_locally_on_format',
  'saved node subtitle must not include the long "saved locally on" label'
)
assertNotIncludes(rowSubtitleBody, 'DateUtils.toDateString', 'saved node subtitle must not include the full timestamp')

// Stable row identity store, mirroring the blocked-member row pattern.
assertIncludes(page, 'private nodeRowsByName: Map<string, SavedNodeRow>', 'page must keep stable row objects by node name')
assertIncludes(page, 'private ensureNodeRowsForNames', 'page must expose a name-diff helper that reuses row objects')
assertIncludes(page, 'private nodeRowForName', 'page must create/reuse exactly one row object per node name')
assertIncludes(page, '.applyNode(', 'enrichment must update the existing row object in place')

// ForEach must render the canonical row store and key on identity only.
// Scope to the page struct so we read the page build(), not the row view build().
const pageStructStart = page.indexOf('export struct SavedNodesPage')
if (pageStructStart < 0) {
  fail('missing export struct SavedNodesPage')
}
const pageStruct = page.slice(pageStructStart)
const buildBody = methodBody(pageStruct, '  build')
assertIncludes(buildBody, 'Column() {', 'SavedNodesPage must own a full-page container like MyNodesPage')
assertIncludes(
  buildBody,
  ".backgroundColor($r('sys.color.ohos_id_color_sub_background'))",
  'SavedNodesPage must use the sub-background so saved-node cards remain visually distinct'
)
assertIncludes(buildBody, 'ForEach(this.nodes, (item: SavedNodeRow)', 'SavedNodesPage must render the canonical row store')
assertIncludes(buildBody, '`saved-node-${item.name}`', 'saved node row key must stay stable by node name')

// The previous implementation embedded the derived avatar URL in the key to
// force a rebuild when icons resolved. That is exactly the key churn this
// migration removes; guard against any churn token reappearing in a key.
assertNotIncludes(page, '${this.nodeIcon(item)}', 'saved node key must not embed the derived node icon URL')
assertNotIncludes(page, 'Date.now()', 'saved node row must not use Date.now key/version churn')
for (const churn of ['-${this.nodeIcon', '-${item.icon}', '-${item.updatedAt}', '-${item.savedAt}']) {
  assertNotIncludes(buildBody, churn, `ForEach key must not append churn token ${churn}`)
}

// In-place mutation: data must flow through applyNodes (reuse + @Trace update),
// never by replacing the row array with raw SavedNode[] plain objects.
const applyNodesBody = methodBody(page, 'private applyNodes')
assertIncludes(applyNodesBody, 'this.ensureNodeRowsForNames', 'applyNodes must reuse stable row objects before applying values')
assertIncludes(applyNodesBody, '.applyNode(', 'applyNodes must update row @Trace fields in place')

const loadNodesBody = methodBody(page, 'private loadNodes')
assertIncludes(loadNodesBody, 'this.applyNodes(', 'loadNodes must route through the stable row store')
assertNotIncludes(loadNodesBody, 'this.nodes = items', 'loadNodes must not replace rows with raw SavedNode[] objects')

const enrichBody = methodBody(page, 'private enrichMissingNodeIcons')
assertIncludes(enrichBody, 'this.applyNodes(enriched)', 'enrichment must apply resolved icons through the stable row store')
assertIncludes(enrichBody, 'this.applyNodes(next)', 'persisted metadata must apply through the stable row store')
assertNotIncludes(enrichBody, 'this.nodes = enriched', 'enrichment must not replace same-name rows with new plain objects')
assertNotIncludes(enrichBody, 'this.nodes = next', 'enrichment must not replace same-name rows with new plain objects')

console.log('PASS: saved nodes row state V2 contract')
