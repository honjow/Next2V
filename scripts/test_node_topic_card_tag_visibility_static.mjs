#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readdirSync, readFileSync, statSync } from 'node:fs'

const topicCard = readFileSync('shared/src/main/ets/components/TopicCard.ets', 'utf8')
const nodeTopicPagePath = 'feature/node/src/main/ets/pages/NodeTopicPage.ets'
const nodeTopicPage = readFileSync(nodeTopicPagePath, 'utf8')

function mustContain(text, needle, label = needle) {
  assert.notEqual(text.indexOf(needle), -1, `${label} not found`)
}

mustContain(topicCard, '@Param showNodeTag: boolean = true', 'TopicCard keeps node tag visible by default')
mustContain(topicCard, 'if (this.showNodeTag) {\n          NodeTag({ nodeName: this.item.node.name, nodeTitle: this.item.node.title })', 'TopicCard gates NodeTag rendering')
mustContain(topicCard, 'if (this.showNodeTag) {\n          NodeTag({ nodeName: this.item.node.name, nodeTitle: this.item.node.title })\n            .onClick(() => {\n              if (this.onNodeClick) { this.onNodeClick() }\n            })\n        }', 'TopicCard keeps node click handler with visible NodeTag')

mustContain(nodeTopicPage, 'showNodeTag: false', 'NodeTopicPage hides the redundant per-card node tag')

// Skip build outputs, dependency mirrors (oh_modules/node is a symlink back to feature/node),
// and sibling git worktrees so the scan only sees real first-party source once.
const EXCLUDED_DIRS = new Set([
  '.git', '.claude', 'oh_modules', 'node_modules', 'build', '.preview', '.hvigor', '.hermes-artifacts',
])

function collectEtsFiles(dir) {
  const files = []
  for (const entry of readdirSync(dir)) {
    if (EXCLUDED_DIRS.has(entry)) {
      continue
    }
    const path = `${dir}/${entry}`
    const stat = statSync(path)
    if (stat.isDirectory()) {
      files.push(...collectEtsFiles(path))
    } else if (path.endsWith('.ets')) {
      files.push(path)
    }
  }
  return files
}

const hiddenTagCallers = collectEtsFiles('.')
  .filter(path => readFileSync(path, 'utf8').includes('showNodeTag: false'))
  .map(path => path.replace(/^\.\//, ''))
assert.deepEqual(hiddenTagCallers, [nodeTopicPagePath], 'Only NodeTopicPage should hide TopicCard node tags')

console.log('test_node_topic_card_tag_visibility_static: PASS')
