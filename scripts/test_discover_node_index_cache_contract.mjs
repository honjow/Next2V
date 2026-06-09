#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const indexPage = readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
const discoverPage = readFileSync('feature/node/src/main/ets/pages/DiscoverPage.ets', 'utf8')
const discoverCoordinator = readFileSync('feature/node/src/main/ets/model/DiscoverPageCoordinator.ets', 'utf8')
// The node-index concern was split out of NodeViewModel (topics) into its own NodeIndexViewModel, which
// owns the load phase, the repository-backed fetch, and the publish policy that this contract pins.
const nodeVm = readFileSync('feature/node/src/main/ets/viewmodel/NodeIndexViewModel.ets', 'utf8')
const searchUtils = readFileSync('shared/src/main/ets/utils/NodeSearchUtils.ets', 'utf8')
const sharedIndex = readFileSync('shared/src/main/ets/Index.ets', 'utf8')
const repo = readFileSync('shared/src/main/ets/cache/NodeIndexRepository.ets', 'utf8')
const apiService = readFileSync('shared/src/main/ets/network/ApiService.ets', 'utf8')
const nodeParser = readFileSync('shared/src/main/ets/parser/V2exNodeParser.ets', 'utf8')
const searchCoordinator = readFileSync('entry/src/main/ets/model/SearchLocalDataCoordinator.ets', 'utf8')
const savedNodesPage = readFileSync('entry/src/main/ets/pages/SavedNodesPage.ets', 'utf8')
const myNodesPage = readFileSync('entry/src/main/ets/pages/MyNodesPage.ets', 'utf8')

function mustContain(text, needle, label = needle) {
  assert.notEqual(text.indexOf(needle), -1, `${label} not found`)
}

function methodBody(text, signature) {
  const start = text.indexOf(signature)
  assert.notEqual(start, -1, `${signature} not found`)
  const braceStart = text.indexOf('{', start)
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    if (text[i] === '{') depth++
    if (text[i] === '}') depth--
    if (depth === 0) return text.slice(braceStart + 1, i)
  }
  assert.fail(`${signature} body end not found`)
}

mustContain(indexPage, '.animationDuration(0)', 'user-preserved tab animationDuration(0)')

mustContain(nodeVm, "nodeIndexPhase: NodeIndexLoadPhase = 'idle'", 'explicit node index phase')
mustContain(nodeVm, 'hasNodeIndexSettled(): boolean', 'settled phase helper')
// The search refactor moved the node-search results surface (and its settle-gated empty state) off the
// now-pure-browsing Discover page onto the dedicated NodePickerPage. The same "no empty-state flash before
// the index loads" intent is enforced there by gating the empty state behind load completion: it renders
// only when NOT loading and there is no error and the result count is 0.
const nodePickerPage = readFileSync('feature/node/src/main/ets/pages/NodePickerPage.ets', 'utf8')
const buildBody = methodBody(discoverPage, 'build()')
const pickerBuildBody = methodBody(nodePickerPage, 'build()')
const loadingGateIndex = pickerBuildBody.indexOf('this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0')
const emptyStateIndex = pickerBuildBody.indexOf('NodePickerEmptyState()')
assert.ok(loadingGateIndex !== -1, 'node picker must keep a loading-phase branch before the empty state')
assert.ok(emptyStateIndex !== -1 && loadingGateIndex < emptyStateIndex, 'empty state must only render after node index settles (loading branch precedes it)')

mustContain(repo, 'export class NodeIndexRepository', 'shared node index repository')
mustContain(repo, 'private static memoryNodes: V2exNode[] | null = null', 'app-level memory cache')
mustContain(repo, 'NodeSearchUtils.sortByPopularity', 'repository owns sorted cache')
mustContain(sharedIndex, "export { NodeIndexRepository } from './cache/NodeIndexRepository'", 'shared export')

mustContain(nodeVm, 'NodeIndexRepository.getNodes', 'viewmodel uses repository')
mustContain(searchCoordinator, 'NodeIndexRepository.getNodes', 'search uses repository')
mustContain(savedNodesPage, 'NodeIndexRepository.getNodes', 'saved nodes uses repository')
mustContain(myNodesPage, 'NodeIndexRepository.getNodes', 'my nodes uses repository')
assert.equal(nodeVm.includes('this.api.getAllNodes()'), false, 'NodeViewModel must not fetch node index directly')
assert.equal(searchCoordinator.includes('api.getAllNodes()'), false, 'Search coordinator must not fetch node index directly')
assert.equal(savedNodesPage.includes('this.api.getAllNodes()'), false, 'SavedNodesPage must not fetch node index directly')
assert.equal(myNodesPage.includes('this.api.getAllNodes()'), false, 'MyNodesPage must not fetch node index directly')

const filterBody = methodBody(searchUtils, 'static filter(nodes: V2exNode[], keyword: string): V2exNode[]')
assert.equal(filterBody.includes('NodeSearchUtils.sortByPopularity(nodes)'), false, 'empty keyword must not sort again')
mustContain(filterBody, 'return nodes', 'empty keyword reuses already-sorted node array')

mustContain(nodeVm, 'publishDefaultNodes?: boolean', 'publish policy option')
const initialLoadBody = methodBody(discoverPage, 'private requestInitialLoad(reason: string): void')
assert.equal(initialLoadBody.includes('loadAllNodes'), false, 'Discover default entry must not load the full node index')
// Node-search-intent publishing also moved to the picker surface: loadAllNodes() defaults to publishing the
// default node list (publishDefaultNodes !== false), and setNodeFilter narrows by keyword while keeping that
// publish policy. The dedicated picker drives both on entry / keyword change.
mustContain(nodeVm, 'const publishDefaultNodes = loadOptions.publishDefaultNodes !== false', 'loadAllNodes publishes the default node list unless explicitly disabled')
mustContain(nodeVm, 'setNodeFilter(keyword: string): void', 'node search intent narrows published results by keyword')
mustContain(nodePickerPage, 'keywordChangeAction: (value: string) => { this.vm.setNodeFilter(value) }', 'node picker wires keyword changes into the publish policy')
assert.equal(discoverCoordinator.includes('defaultNodePreview'), false, 'Discover should not use capped all-node preview')
mustContain(buildBody, 'this.NodeNavigationSections()', 'default branch uses node navigation section')
mustContain(discoverPage, "AppStrings.text($r('app.string.discover_node_navigation')", 'Discover node section title should use i18n resource')
// Whitespace-flattened: the formatter wraps the `this.api.getNodeNavigationSections()` chain across lines.
mustContain(discoverPage.replace(/\s+/g, ' '), 'this.api .getNodeNavigationSections()', 'Discover loads webpage node navigation')
mustContain(apiService, 'getNodeNavigationSections(): Promise<V2exNodeNavigationSection[]>', 'ApiService exposes node navigation')
mustContain(apiService, "this.http.getText('/?tab=nodes')", 'ApiService loads V2EX node navigation tab')
// Whitespace-flattened: the formatter wraps the .filter predicate across lines.
const apiServiceFlat = apiService.replace(/\s+/g, ' ')
mustContain(apiServiceFlat, "section.titleKey === 'discover_node_navigation_hottest' || section.titleKey === 'discover_node_navigation_recently_created'", 'home navigation must only contribute first two sections by i18n key, not localized text')
assert.equal(apiService.includes("section.title !== '节点导航' && section.title !== 'V2EX / Curated Nodes'"), false, 'structured navigation must not filter by wrapper display strings')
mustContain(nodeParser, 'extractNodeNavigationSections', 'node parser extracts webpage node navigation')
mustContain(nodeParser, 'extractStructuredNodeNavigationSections', 'node parser extracts grouped node navigation rows')
mustContain(nodeParser, "return 'discover_node_navigation_hottest'", 'Hottest Nodes should map to an i18n resource key')
assert.equal(nodeParser.includes("return '最热节点'"), false, 'parser must not hardcode localized section text')

mustContain(repo, "DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_load_start'", 'load start diagnostics')
mustContain(repo, "DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_load_done'", 'load done diagnostics')
mustContain(nodeVm, "DiagnosticLogger.info('ui_lifecycle', 'node_index_publish_done'", 'publish diagnostics')

console.log('test_discover_node_index_cache_contract: PASS')
