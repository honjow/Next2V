#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const indexPage = readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
const discoverPage = readFileSync('feature/node/src/main/ets/pages/DiscoverPage.ets', 'utf8')

function mustContain(text, needle, label = needle) {
  assert.notEqual(text.indexOf(needle), -1, `${label} not found`)
}

function methodBody(text, signature) {
  const start = text.indexOf(signature)
  assert.notEqual(start, -1, `${signature} not found`)
  const braceStart = text.indexOf('{', start)
  assert.notEqual(braceStart, -1, `${signature} body start not found`)
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    if (text[i] === '{') {
      depth++
    } else if (text[i] === '}') {
      depth--
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  assert.fail(`${signature} body end not found`)
}

mustContain(indexPage, 'DiscoverPage({', 'DiscoverPage construction')
mustContain(indexPage, 'currentTab: this.ct', 'Index must pass current tab to DiscoverPage')
assert.equal(indexPage.includes('.animationDuration(0)'), true, 'Index must preserve user-restored HDS tab animationDuration(0)')

mustContain(discoverPage, '@Param currentTab: number = 0', 'DiscoverPage currentTab prop')
mustContain(discoverPage, "@Monitor('currentTab')", 'DiscoverPage currentTab watcher')
mustContain(discoverPage, 'private hasStartedInitialLoad: boolean = false', 'DiscoverPage initial load once guard')
mustContain(discoverPage, 'private requestInitialLoad(reason: string): void', 'DiscoverPage guarded initial load helper')
mustContain(discoverPage, 'this.requestInitialLoad(\'aboutToAppear\')', 'aboutToAppear delegates to guarded initial load')
mustContain(discoverPage, 'this.requestInitialLoad(\'currentTabChanged\')', 'current tab watcher triggers guarded initial load')

const aboutBody = methodBody(discoverPage, 'aboutToAppear(): void')
assert.equal(aboutBody.includes('this.vm.loadAllNodes()'), false, 'aboutToAppear must not directly load all nodes')
assert.equal(aboutBody.includes('this.loadLocalNodeSections()'), false, 'aboutToAppear must not directly load local node sections')
assert.equal(aboutBody.includes('this.loadNodeNavigationSections()'), false, 'aboutToAppear must not directly load node navigation')
assert.equal(aboutBody.includes('this.loadTopicSurface()'), false, 'aboutToAppear must not directly load topic surface')

const requestBody = methodBody(discoverPage, 'private requestInitialLoad(reason: string): void')
mustContain(requestBody, 'if (this.hasStartedInitialLoad)', 'initial load helper must guard repeated loads')
mustContain(requestBody, 'if (this.currentTab !== 1)', 'initial load helper must skip off-tab materialization')
mustContain(requestBody, 'this.hasStartedInitialLoad = true', 'initial load helper must mark started before heavy work')

const gateIndex = requestBody.indexOf('if (this.currentTab !== 1)')
const startedIndex = requestBody.indexOf('this.hasStartedInitialLoad = true')
const loadLocalIndex = requestBody.indexOf('this.loadLocalNodeSections()')
const loadNavigationIndex = requestBody.indexOf('this.loadNodeNavigationSections()')
const loadTopicIndex = requestBody.indexOf('this.loadTopicSurface()')
assert.ok(gateIndex !== -1 && startedIndex !== -1, 'initial load gate and started guard must exist')
assert.equal(requestBody.includes('this.vm.loadAllNodes('), false, 'initial Discover entry must not load the full node index')
assert.ok(loadLocalIndex !== -1, 'initial load helper must load local node sections after selected')
assert.ok(loadNavigationIndex !== -1, 'initial load helper must load node navigation after selected')
assert.ok(loadTopicIndex !== -1, 'initial load helper must load topic surface after selected')
assert.ok(gateIndex < loadLocalIndex, 'currentTab gate must precede loadLocalNodeSections')
assert.ok(gateIndex < loadNavigationIndex, 'currentTab gate must precede loadNodeNavigationSections')
assert.ok(gateIndex < loadTopicIndex, 'currentTab gate must precede loadTopicSurface')
assert.ok(startedIndex < loadLocalIndex, 'started guard should be set before loadLocalNodeSections')
assert.ok(startedIndex < loadNavigationIndex, 'started guard should be set before loadNodeNavigationSections')
assert.ok(startedIndex < loadTopicIndex, 'started guard should be set before loadTopicSurface')

// The node-search keyword handler was moved off the Discover surface entirely by the search refactor
// (Discover is now pure browsing; node search lives in NodePickerPage, which owns the loadAllNodes-on-entry
// node index). DiscoverPage no longer has an onKeywordChanged handler, so the "node index loads only after
// node-search intent" guard now applies to the picker. The invariant that *Discover entry* never loads the
// full node index is still enforced here by the aboutToAppear + requestInitialLoad assertions above.
assert.equal(discoverPage.includes('private onKeywordChanged('), false, 'Discover must not carry node-search keyword handling after the search refactor')
const nodePickerPage = readFileSync('feature/node/src/main/ets/pages/NodePickerPage.ets', 'utf8')
assert.ok(nodePickerPage.includes('this.vm.loadAllNodes()'), 'node index loads on the dedicated node picker (node-search surface), not on Discover entry')

const refreshBody = methodBody(discoverPage, 'private async refreshDiscover(): Promise<void>')
assert.equal(refreshBody.includes('loadAllNodes'), false, 'pull refresh must not force-refresh the full node index')
assert.ok(refreshBody.includes('await this.loadTopicSurface(true)'), 'pull refresh should refresh topic surface in place')

console.log('test_discover_lazy_initial_load_contract: PASS')
