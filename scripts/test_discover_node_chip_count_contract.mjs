#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const componentPath = 'feature/node/src/main/ets/components/DiscoverPageComponents.ets'
const pagePath = 'feature/node/src/main/ets/pages/DiscoverPage.ets'
const component = readFileSync(componentPath, 'utf8')
const page = readFileSync(pagePath, 'utf8')

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

function structBody(text, name) {
  const marker = `export struct ${name}`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing struct: ${name}`)
  }
  const braceStart = text.indexOf('{', start)
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') {
      depth += 1
    } else if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  fail(`unterminated struct: ${name}`)
}

const chip = structBody(component, 'DiscoverNodeChip')

assertIncludes(
  chip,
  '@Param node: SavedNode',
  'Discover node chip must keep using saved-node data'
)

assertNotIncludes(
  chip,
  'this.node.topics',
  'Discover node chips must not render cached local followed-node topic counts'
)

assertNotIncludes(
  page,
  'showTopicCount',
  'Discover page must not expose a cached topic-count opt-in for local node chips'
)

console.log('PASS: discover node chip count contract')
