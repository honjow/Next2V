#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const api = fs.readFileSync(path.join(repo, 'shared/src/main/ets/network/ApiService.ets'), 'utf8')
const tabParser = fs.readFileSync(path.join(repo, 'shared/src/main/ets/parser/V2exTabParser.ets'), 'utf8')

function methodBody(source, signature, nextSignature) {
  const start = source.indexOf(signature)
  assert.notEqual(start, -1, `${signature} must exist`)
  const end = nextSignature ? source.indexOf(nextSignature, start + signature.length) : source.length
  assert.notEqual(end, -1, `${nextSignature} boundary must exist`)
  return source.slice(start, end)
}

const hotTab = methodBody(api, 'async getHotTabTopics()', 'async getRecentTopics')
assert.match(hotTab, /V2exTabParser\.parseTopicList\(html\)/, 'hot tab must parse topic cards directly from HTML')
assert.doesNotMatch(hotTab, /getBatchTopics\(ids\)/, 'hot tab must not fan out to legacy /api/topics/show.json')

const recent = methodBody(api, 'async getRecentTopics', 'async getTopicById')
assert.match(recent, /V2exTabParser\.parseTopicList\(html\)/, 'recent topics must parse topic cards directly from HTML')
assert.doesNotMatch(recent, /getBatchTopics\(ids\)/, 'recent topics must not fan out to legacy /api/topics/show.json')

const nodePage = methodBody(api, 'async getNodeTopicsPage', 'async getReplies')
assert.match(nodePage, /V2exTabParser\.parseTopicList\(html\)/, 'node page must parse topic cards directly from HTML')
assert.doesNotMatch(nodePage, /getBatchTopics\(snapshot\.topicIds\)/, 'node page must not fan out to legacy /api/topics/show.json')

const topicById = methodBody(api, 'async getTopicById', '/** Get topics by username')
assert.match(topicById, /ApiConstants\.API_TOPIC_SHOW/, 'topic detail may use single-topic legacy JSON for canonical rendered content')
assert.match(topicById, /content\/content_rendered is the\s*\/\/ stable input|stable input for V2Next/, 'topic detail must document why JSON remains primary')
assert.match(topicById, /catch \(error\)[\s\S]*this\.http\.getText\(path\)[\s\S]*topicFromHtml\(topicId, html\)/, 'topic detail must fall back to HTML only when JSON is unavailable')

const member = methodBody(api, 'async getMember(username: string)', '/** Get topics, replies')
assert.match(member, /this\.http\.getText\(`\/member\/\$\{encodeURIComponent\(clean\)\}`\)/, 'member profile must fetch HTML member page before legacy JSON API')
assert.match(member, /catch \(error\)/, 'member profile may fall back when HTML parsing fails')

assert.match(tabParser, /static parseTopicList\(html: string\): V2exTopic\[\]/, 'V2exTabParser must expose HTML topic parser')
assert.match(tabParser, /class=\["'\]cell(?: item|\(\?:\\s\+item)/, 'HTML parser must target V2EX topic list cells')

const fixture = fs.readFileSync(path.join(repo, 'scripts/fixtures/hot_tab_main_list_sample.html'), 'utf8')
assert.match(fixture, /topic-link-1001/, 'fixture sanity')

console.log('legacy JSON API rate-limit contract ok')
