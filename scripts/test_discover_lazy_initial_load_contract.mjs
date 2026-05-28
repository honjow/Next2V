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

mustContain(discoverPage, 'currentTab: number = 0', 'DiscoverPage currentTab prop')
mustContain(discoverPage, "@Watch('onCurrentTabChanged')", 'DiscoverPage currentTab watcher')
mustContain(discoverPage, 'private hasStartedInitialLoad: boolean = false', 'DiscoverPage initial load once guard')
mustContain(discoverPage, 'private requestInitialLoad(reason: string): void', 'DiscoverPage guarded initial load helper')
mustContain(discoverPage, 'this.requestInitialLoad(\'aboutToAppear\')', 'aboutToAppear delegates to guarded initial load')
mustContain(discoverPage, 'this.requestInitialLoad(\'currentTabChanged\')', 'current tab watcher triggers guarded initial load')

const aboutBody = methodBody(discoverPage, 'aboutToAppear(): void')
assert.equal(aboutBody.includes('this.vm.loadAllNodes()'), false, 'aboutToAppear must not directly load all nodes')
assert.equal(aboutBody.includes('this.loadLocalNodeSections()'), false, 'aboutToAppear must not directly load local node sections')
assert.equal(aboutBody.includes('this.loadTopicSurface()'), false, 'aboutToAppear must not directly load topic surface')

const requestBody = methodBody(discoverPage, 'private requestInitialLoad(reason: string): void')
mustContain(requestBody, 'if (this.hasStartedInitialLoad)', 'initial load helper must guard repeated loads')
mustContain(requestBody, 'if (this.currentTab !== 1)', 'initial load helper must skip off-tab materialization')
mustContain(requestBody, 'this.hasStartedInitialLoad = true', 'initial load helper must mark started before heavy work')

const gateIndex = requestBody.indexOf('if (this.currentTab !== 1)')
const startedIndex = requestBody.indexOf('this.hasStartedInitialLoad = true')
const loadNodesIndex = requestBody.indexOf('this.vm.loadAllNodes(')
const loadLocalIndex = requestBody.indexOf('this.loadLocalNodeSections()')
const loadTopicIndex = requestBody.indexOf('this.loadTopicSurface()')
assert.ok(gateIndex !== -1 && startedIndex !== -1, 'initial load gate and started guard must exist')
assert.ok(loadNodesIndex !== -1, 'initial load helper must load all nodes after selected')
assert.ok(loadLocalIndex !== -1, 'initial load helper must load local node sections after selected')
assert.ok(loadTopicIndex !== -1, 'initial load helper must load topic surface after selected')
assert.ok(gateIndex < loadNodesIndex, 'currentTab gate must precede loadAllNodes')
assert.ok(gateIndex < loadLocalIndex, 'currentTab gate must precede loadLocalNodeSections')
assert.ok(gateIndex < loadTopicIndex, 'currentTab gate must precede loadTopicSurface')
assert.ok(startedIndex < loadNodesIndex, 'started guard should be set before loadAllNodes')
assert.ok(startedIndex < loadLocalIndex, 'started guard should be set before loadLocalNodeSections')
assert.ok(startedIndex < loadTopicIndex, 'started guard should be set before loadTopicSurface')

console.log('test_discover_lazy_initial_load_contract: PASS')
