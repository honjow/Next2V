#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing static contract in ${file}: ${needle}`)
  }
}

const indexPath = 'entry/src/main/ets/pages/Index.ets'
const coordinatorPath = 'entry/src/main/ets/model/IndexRouteCoordinator.ets'
const index = source(indexPath)
const coordinator = source(coordinatorPath)

assertIncludes(indexPath, index, 'pm(name: string, param: Object)')
assertIncludes(indexPath, index, 'this.destination(IndexRouteCoordinator.destination(name, param))')
assertIncludes(coordinatorPath, coordinator, 'DESTINATION_FAMILIES')
assertIncludes(coordinatorPath, coordinator, 'DESTINATION_TITLES')
assertIncludes(coordinatorPath, coordinator, 'static destination(name: string, param: Object)')

const pmMatch = index.match(/pm\(name: string, param: Object\) \{([\s\S]*?)\n  \}/)
if (!pmMatch || !pmMatch[1]) {
  fail('Index.pm builder was not found')
}
const pmBody = pmMatch[1]
if (/name\s*={2,3}/.test(pmBody) || /HdsNavDestination\s*\(/.test(pmBody)) {
  fail('Index.pm must stay descriptor-only and must not own route branches')
}

const routeNames = [
  'TopicDetail',
  'ReplyEditor',
  'V2exWebLogin',
  'V2exNativeLogin',
  'NodePicker',
  'Search',
  'TopicEditor',
  'MyTopics',
  'MyNodes',
  'AccountBlacklist',
  'AccountFollowing',
  'Settings',
  'Storage',
  'HomeNodeSettings',
  'ReadingSettings',
  'Account',
  'SavedTopics',
  'ViewedTopics',
  'SavedNodes',
  'About',
  'ImagePreview',
  'NodeTopicList',
  'UserProfile',
  'UserTopics',
  'UserReplies',
]

for (const routeName of routeNames) {
  assertIncludes(coordinatorPath, coordinator, `'${routeName}':`)
}

console.log('PASS: index destination descriptor contract')
