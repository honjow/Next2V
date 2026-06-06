#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const exists = (rel) => fs.existsSync(path.join(repo, rel))
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

const findMatchingBrace = (text, openBraceIndex) => {
  let depth = 0
  let quote = null
  let escaped = false
  let lineComment = false
  let blockComment = false

  for (let i = openBraceIndex; i < text.length; i += 1) {
    const char = text[i]
    const next = text[i + 1]

    if (lineComment) {
      if (char === '\n') lineComment = false
      continue
    }
    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false
        i += 1
      }
      continue
    }
    if (quote !== null) {
      if (escaped) {
        escaped = false
      } else if (char === '\\') {
        escaped = true
      } else if (char === quote) {
        quote = null
      }
      continue
    }

    if (char === '/' && next === '/') {
      lineComment = true
      i += 1
      continue
    }
    if (char === '/' && next === '*') {
      blockComment = true
      i += 1
      continue
    }
    if (char === '\'' || char === '"' || char === '`') {
      quote = char
      continue
    }
    if (char === '{') {
      depth += 1
    } else if (char === '}') {
      depth -= 1
      if (depth === 0) return i
    }
  }

  return -1
}

const extractMethodBody = (text, methodName) => {
  const methodRegex = new RegExp(`(?:static\\s+async|private\\s+static\\s+async|private\\s+static|static)\\s+${methodName}\\s*\\(`)
  const methodMatch = methodRegex.exec(text)
  assert(methodMatch !== null, `CollectionSettings.${methodName} method missing`)
  const openBraceIndex = text.indexOf('{', methodMatch.index)
  assert(openBraceIndex !== -1, `CollectionSettings.${methodName} opening brace missing`)
  const closeBraceIndex = findMatchingBrace(text, openBraceIndex)
  assert(closeBraceIndex !== -1, `CollectionSettings.${methodName} closing brace missing`)
  return text.slice(openBraceIndex + 1, closeBraceIndex)
}

const collectionRel = 'shared/src/main/ets/settings/CollectionSettings.ets'
const typesRel = 'shared/src/main/ets/settings/CollectionTypes.ets'
const limitsRel = 'shared/src/main/ets/settings/CollectionLimits.ets'
const parsersRel = 'shared/src/main/ets/settings/CollectionParsers.ets'
const publisherRel = 'shared/src/main/ets/settings/LocalDataPublisher.ets'

for (const rel of [collectionRel, typesRel, limitsRel, parsersRel, publisherRel]) {
  assert(exists(rel), `${rel} must exist`)
}

const collectionText = read(collectionRel)
assert(/export\s+class\s+CollectionSettings/.test(collectionText), 'CollectionSettings facade class must remain exported')

for (const method of [
  'loadSavedTopics',
  'saveTopic',
  'removeTopic',
  'isTopicSaved',
  'loadSavedNodes',
  'saveNode',
  'removeNode',
  'updateSavedNodeMetadata',
  'updateSavedNodesMetadata',
  'isNodeSaved',
  'loadViewedTopics',
  'recordViewedTopic',
  'getTopicReadFloor',
  'saveTopicReadFloor',
  'loadTopicReadPositions',
  'syncTopicReadStates',
  'markTopicRead',
  'loadTopicReadStates',
  'loadLocalContentStats',
  'clearAll',
  'cleanNodeTitle',
]) {
  extractMethodBody(collectionText, method)
}

const limitsText = read(limitsRel)
const expectedLimits = new Map([
  ['MAX_SAVED_TOPICS', '100'],
  ['MAX_SAVED_NODES', '80'],
  ['MAX_VIEWED_TOPICS', '100'],
  ['MAX_READ_POSITIONS', '200'],
  ['MAX_READ_STATES', '500'],
])
for (const [name, value] of expectedLimits) {
  assert(limitsText.includes(`export const ${name}: number = ${value}`), `${name} must remain ${value}`)
}

const expectedKeys = [
  ['KEY_SAVED_TOPICS', 'savedTopics'],
  ['KEY_SAVED_NODES', 'savedNodes'],
  ['KEY_VIEWED_TOPICS', 'viewedTopics'],
  ['KEY_TOPIC_READ_POSITIONS', 'topicReadPositions'],
  ['KEY_TOPIC_READ_STATES', 'topicReadStates'],
]
for (const [name, value] of expectedKeys) {
  assert(collectionText.includes(`const ${name}: string = '${value}'`), `${name} must remain '${value}' for legacy traceability`)
}

for (const snippet of [
  "import { relationalStore } from '@kit.ArkData'",
  "import { LocalDataStore } from '../storage/LocalDataStore'",
  "import { deleteKeysAndFlush, withPreferencesStore } from './SettingsStorage'",
  'LocalDataStore.open(context)',
  'deleteLegacyCollectionKeysBestEffort',
]) {
  assert(collectionText.includes(snippet), `CollectionSettings missing RDB/legacy cleanup contract: ${snippet}`)
}

for (const forbidden of [
  'preferences.getPreferences',
  'store.getSync(KEY_SAVED_TOPICS',
  'store.getSync(KEY_SAVED_NODES',
  'store.getSync(KEY_VIEWED_TOPICS',
  'store.getSync(KEY_TOPIC_READ_POSITIONS',
  'store.getSync(KEY_TOPIC_READ_STATES',
  'store.putSync(KEY_SAVED_TOPICS',
  'store.putSync(KEY_SAVED_NODES',
  'store.putSync(KEY_VIEWED_TOPICS',
  'store.putSync(KEY_TOPIC_READ_POSITIONS',
  'store.putSync(KEY_TOPIC_READ_STATES',
  'parseSavedTopics',
  'parseSavedNodes',
  'parseViewedTopics',
  'parseTopicReadPositions',
  'parseTopicReadStates',
]) {
  assert(!collectionText.includes(forbidden), `CollectionSettings must not dual-read/write Preferences or parser fallback: ${forbidden}`)
}

const rdbContracts = [
  'collection_saved_topics',
  'collection_saved_nodes',
  'collection_viewed_topics',
  'collection_topic_read_positions',
  'collection_topic_read_states',
  'INSERT INTO collection_saved_topics',
  'INSERT INTO collection_saved_nodes',
  'INSERT INTO collection_viewed_topics',
  'INSERT INTO collection_topic_read_positions',
  'INSERT INTO collection_topic_read_states',
  'ORDER BY saved_at DESC, topic_id DESC LIMIT 100',
  'ORDER BY saved_at DESC, node_name ASC LIMIT 80',
  'ORDER BY viewed_at DESC, topic_id DESC LIMIT 100',
  'ORDER BY updated_at DESC, topic_id DESC LIMIT 200',
  'ORDER BY updated_at DESC, topic_id DESC LIMIT 500',
  'SELECT COUNT(*) AS count_value FROM collection_saved_topics',
  'SELECT COUNT(*) AS count_value FROM collection_saved_nodes',
  'SELECT COUNT(*) AS count_value FROM collection_viewed_topics',
]
for (const snippet of rdbContracts) {
  assert(collectionText.includes(snippet), `CollectionSettings missing RDB contract: ${snippet}`)
}

for (const method of ['saveTopic', 'removeTopic', 'saveNode', 'removeNode', 'recordViewedTopic']) {
  const body = extractMethodBody(collectionText, method)
  assert(body.includes('LocalDataPublisher.touchLocalData()'), `${method} must touch local data after successful persistence`)
}

const clearAllBody = extractMethodBody(collectionText, 'clearAll')
for (const sql of [
  'SQL_CLEAR_SAVED_TOPICS',
  'SQL_CLEAR_SAVED_NODES',
  'SQL_CLEAR_VIEWED_TOPICS',
  'SQL_CLEAR_TOPIC_READ_POSITIONS',
  'SQL_CLEAR_TOPIC_READ_STATES',
]) {
  assert(clearAllBody.includes(`await store.executeSql(${sql})`), `clearAll must delete ${sql}`)
}
assert(clearAllBody.includes('LocalDataPublisher.clearTopicReadStates()'), 'clearAll must publish empty read states')
assert(clearAllBody.includes('savedTopicCount: 0'), 'clearAll must publish zero saved topic count')
assert(clearAllBody.includes('savedNodeCount: 0'), 'clearAll must publish zero saved node count')
assert(clearAllBody.includes('viewedTopicCount: 0'), 'clearAll must publish zero viewed topic count')
assert(clearAllBody.indexOf('deleteLegacyCollectionKeysBestEffort') > clearAllBody.indexOf('LocalDataPublisher.touchLocalData()'), 'legacy keys must be deleted only after RDB clear succeeds')

const publisherText = read(publisherRel)
const storageKeyRefs = [...publisherText.matchAll(/StorageKeys\.(\w+)/g)].map((match) => match[1])
// Pure-V2: the local-content counts and the local-data-changed signal now live exclusively in the
// AppStorageV2 mirrors (LocalContentStatsState + LocalDataSignalState). The only AppStorage projection
// LocalDataPublisher still owns is the TOPIC_READ_STATES dual-write (its V1 readers have not migrated).
const allowedPublisherKeys = new Set([
  'TOPIC_READ_STATES',
])
for (const key of storageKeyRefs) {
  assert(allowedPublisherKeys.has(key), `LocalDataPublisher must not publish StorageKeys.${key} (counts + signal are V2-only)`)
}
assert(storageKeyRefs.length >= 1, 'LocalDataPublisher must keep owning the TOPIC_READ_STATES projection')
// The retired local-content projection must not creep back: no AppStorage write of the count / signal keys.
assert(
  !/setAppStorageValue<[^>]*>\(\s*StorageKeys\.LOCAL_(SAVED_TOPIC_COUNT|SAVED_NODE_COUNT|VIEWED_TOPIC_COUNT|DATA_UPDATED_AT)/.test(publisherText),
  'LocalDataPublisher must not dual-write the retired LOCAL_* AppStorage keys (counts + signal are V2-only)',
)
assert(publisherText.includes('connectLocalContentStats()'), 'LocalDataPublisher must publish local-content counts into the V2 LocalContentStatsState mirror')
assert(publisherText.includes('connectLocalDataSignal()'), 'LocalDataPublisher must publish the local-data-changed signal into the V2 LocalDataSignalState mirror')
assert(!publisherText.includes('preferences.getPreferences'), 'LocalDataPublisher must not own Preferences access')
assert(!publisherText.includes('UIAbilityContext'), 'LocalDataPublisher must not own UIAbilityContext side effects')

const indexText = read('shared/src/main/ets/Index.ets')
assert(indexText.includes("export { CollectionSettings } from './settings/CollectionSettings'"), 'shared Index must keep CollectionSettings facade export')
assert(indexText.includes("} from './settings/CollectionSettings'"), 'shared Index must re-export collection types through CollectionSettings')
assert(!indexText.includes('./settings/CollectionParsers'), 'shared Index must not export CollectionParsers internals')
assert(!indexText.includes('./settings/CollectionLimits'), 'shared Index must not export CollectionLimits internals')
// LocalDataPublisher is a legitimate public export: AccountPage / HomePage / NodeTopicPage /
// UserTopicsPage / UserProfilePage import it from the 'shared' barrel to publish local-content stats.
assert(indexText.includes("export { LocalDataPublisher } from './settings/LocalDataPublisher'"), 'shared Index must export LocalDataPublisher (used cross-module)')

const appIndexText = read('entry/src/main/ets/pages/Index.ets')
assert(/sendNodeTopicAction\(nodeName:\s*string,\s*action:\s*string\)/.test(appIndexText), 'Node topic appbar actions must include the target node name')
// The action-command construction moved out of Index.ets into IndexRouteCoordinator.nodeTopicActionCommand;
// Index.ets now passes nodeName to it, and the coordinator scopes the payload by node name.
assert(appIndexText.includes('IndexRouteCoordinator.nodeTopicActionCommand(nodeName, action'), 'Node topic action command must be built from the target node name via IndexRouteCoordinator')
const routeCoordinatorText = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
assert(routeCoordinatorText.includes("(nodeName || '').trim()"), 'Node topic action payload must be scoped by node name')

const nodeTopicText = read('feature/node/src/main/ets/pages/NodeTopicPage.ets')
assert(nodeTopicText.includes('private currentNodeName(): string'), 'NodeTopicPage must normalize the current node name before saved-node operations')
assert(nodeTopicText.includes('targetNodeName !== this.currentNodeName()'), 'NodeTopicPage must ignore saved-node actions for other live node pages')
assert(nodeTopicText.includes('this.isNodeSaved = nodes.some'), 'NodeTopicPage saved-node state must come from the CollectionSettings result')

const sourceRoots = [
  'entry/src/main/ets',
  'feature/detail/src/main/ets',
  'feature/feed/src/main/ets',
  'feature/node/src/main/ets',
  'feature/settings/src/main/ets',
  'feature/user/src/main/ets',
]
for (const root of sourceRoots) {
  const absRoot = path.join(repo, root)
  if (!fs.existsSync(absRoot)) continue
  const stack = [absRoot]
  while (stack.length > 0) {
    const current = stack.pop()
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name)
      if (entry.isDirectory()) {
        stack.push(full)
      } else if (entry.name.endsWith('.ets')) {
        const rel = path.relative(repo, full)
        const text = fs.readFileSync(full, 'utf8')
        assert(!text.includes('CollectionParsers'), `${rel} must not import CollectionParsers directly`)
        assert(!text.includes('CollectionLimits'), `${rel} must not import CollectionLimits directly`)
        // NOTE: LocalDataPublisher is intentionally NOT forbidden here — it is a public cross-module
        // publisher (exported from the 'shared' barrel) that pages use to publish local-content stats /
        // read-state mirrors. CollectionParsers / CollectionLimits remain shared-internal only.
      }
    }
  }
}

console.log('collection settings contract OK')
