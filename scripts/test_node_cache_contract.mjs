// Contract for node-page offline cache (cache-first + revalidate).
// Static checks across the 4 touched files: node_detail cache kind wired into the shared cache
// lifecycle, NodeViewModel prefill/saver hooks, and NodeTopicPage cache-first wiring.

import { readFileSync } from 'node:fs'

let failures = 0
function check(name, cond) {
  console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}`)
  if (!cond) failures++
}

const policy = readFileSync('shared/src/main/ets/settings/CachePolicy.ets', 'utf8')
check('policy: defines node_detail kind', policy.includes('CACHE_KIND_NODE_DETAIL') && policy.includes("'node_detail'"))
check('policy: node_detail joins CACHE_KINDS_SQL (shared lifecycle)', /CACHE_KINDS_SQL[\s\S]{0,160}CACHE_KIND_NODE_DETAIL/.test(policy))
check('policy: node-detail TTL + key prefix', policy.includes('NODE_DETAIL_TTL_SECONDS') && policy.includes('KEY_PREFIX_NODE_DETAIL'))

const cache = readFileSync('shared/src/main/ets/settings/CacheSettings.ets', 'utf8')
check('cache: load/save node detail APIs', cache.includes('static async loadNodeDetail(') && cache.includes('static async saveNodeDetail('))
check('cache: parseNodeDetail + nodeDetailRowKey', cache.includes('parseNodeDetail') && cache.includes('nodeDetailRowKey'))
check('cache: node_detail row pruning', cache.includes('SQL_PRUNE_NODE_DETAIL_ROWS') && cache.includes('SQL_SELECT_PRUNE_NODE_DETAIL_PAYLOAD_PATHS'))
check('cache: node_detail prune runs inside pruneCache', /SQL_PRUNE_NODE_DETAIL_ROWS/.test(cache))
check('cache: imports V2exNode', cache.includes('V2exNode'))
check('cache: node key is case-insensitive', cache.includes('.trim().toLowerCase()'))

const vm = readFileSync('feature/node/src/main/ets/viewmodel/NodeViewModel.ets', 'utf8')
check('vm: exposes setCacheSavers + prefillFromCache', vm.includes('setCacheSavers(') && vm.includes('prefillFromCache('))
check('vm: prefill fills only empty fields (no clobber of network)', vm.includes('!this.nodeDetail') && vm.includes('this.nodeTopics.length === 0'))
check('vm: writes detail cache on network success', vm.includes('this.nodeDetailCacheSaver(this.nodeDetail)'))
check('vm: writes topics cache on publish', vm.includes('this.nodeTopicsCacheSaver(topics)'))

const page = readFileSync('feature/node/src/main/ets/pages/NodeTopicPage.ets', 'utf8')
check('page: has setupNodeCache + primeFromCache', page.includes('setupNodeCache(') && page.includes('primeFromCache('))
check('page: primes cache then loads network in aboutToAppear', page.includes('this.primeFromCache()') && page.includes('this.loadData()'))
check('page: registers detail + node-list savers', page.includes('CacheSettings.saveNodeDetail') && page.includes('CacheSettings.saveTopicList'))
check('page: node list cache key namespaced (node:)', page.includes("'node:'"))
check('page: imports CacheSettings', page.includes('CacheSettings'))

console.log(`\nnode-cache contract: ${failures} failure(s)`)
process.exit(failures === 0 ? 0 : 1)
