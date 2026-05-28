#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const parserSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/parser/V2exTabParser.ets'), 'utf8')
const apiSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/network/ApiService.ets'), 'utf8')
const fixtureHtml = fs.readFileSync(path.join(repo, 'scripts/fixtures/node_programmer_topic_list_sample.html'), 'utf8')

function decode(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim()
}

function extractFirst(text, pattern) {
  const match = text.match(pattern)
  return match && match[1] ? decode(match[1]) : ''
}

function extractAttr(tag, attr) {
  const match = tag.match(new RegExp(`${attr}=["']([^"']*)["']`, 'i'))
  return match && match[1] ? decode(match[1]) : ''
}

function parseNumber(value) {
  const n = Number.parseInt(String(value || '').replace(/[^0-9]/g, ''), 10)
  return Number.isFinite(n) ? n : 0
}

function productionTopicCellRegex() {
  const match = parserSource.match(/const\s+cellRegex\s*=\s*(\/.*\/gi)/)
  assert.ok(match, 'V2exTabParser.extractTopicCells must define a cellRegex')
  return Function(`return ${match[1]}`)()
}

function extractTopicIdsLikeProduction(html) {
  const ids = new Set()
  const topicLinkRegex = /id=["']topic-link-(\d+)["']/g
  let match
  while ((match = topicLinkRegex.exec(html)) !== null) {
    ids.add(Number.parseInt(match[1], 10))
  }
  if (ids.size > 0) {
    return Array.from(ids)
  }
  const regex = /\/t\/(\d+)/g
  while ((match = regex.exec(html)) !== null) {
    ids.add(Number.parseInt(match[1], 10))
  }
  return Array.from(ids)
}

function parseTopicCellLikeProduction(cell) {
  const linkMatch = cell.match(/<a[^>]*id=["']topic-link-(\d+)["'][^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i) ||
    cell.match(/<a[^>]*href=["']([^"']*\/t\/(\d+)[^"']*)["'][^>]*id=["']topic-link-\d+["'][^>]*>([\s\S]*?)<\/a>/i)
  assert.ok(linkMatch, 'fixture topic cell must include a parseable topic link')
  const id = (linkMatch[1] || '').includes('/t/') ? Number.parseInt(linkMatch[2] || '0', 10) : Number.parseInt(linkMatch[1] || '0', 10)
  const title = (linkMatch[1] || '').includes('/t/') ? linkMatch[3] : linkMatch[3]
  const avatarTag = (cell.match(/<img[^>]*class=["']avatar["'][^>]*>/i) || [''])[0]
  const username = extractAttr(avatarTag, 'alt') || extractFirst(cell, /\/member\/([^"'\s<>]+)/i)
  const avatar = extractAttr(avatarTag, 'src')
  const replies = parseNumber(extractFirst(cell, /<a[^>]*class=["']count_[^"']*["'][^>]*>(\d+)<\/a>/i))
  return { id, title: decode(title), member: { username, avatar }, replies }
}

function parseTopicListLikeProduction(html) {
  const regex = productionTopicCellRegex()
  const cells = []
  let match
  while ((match = regex.exec(html)) !== null) {
    const cell = match[0] || ''
    if (cell.includes('topic-link-')) {
      cells.push(cell)
    }
  }
  const topics = cells.map(parseTopicCellLikeProduction)
  if (topics.length > 0) {
    return topics
  }
  return extractTopicIdsLikeProduction(html).map(id => ({ id, title: '', member: { username: '', avatar: '' }, replies: 0 }))
}

const topics = parseTopicListLikeProduction(fixtureHtml)
assert.equal(topics.length, 1, 'node page should parse exactly one topic card from live-like fixture')
assert.equal(topics[0].id, 1216133)
assert.equal(topics[0].title, '芒果 TV 好像在送免费的 glm 5.1 和 ds v4？', 'node page topic must not fall back to placeholder title')
assert.equal(topics[0].member.username, 'rockxsj', 'node page topic must parse member username')
assert.ok(topics[0].member.avatar.includes('/avatar/001e/1afa/71013_xlarge.png'), 'node page topic must parse member avatar')
assert.equal(topics[0].replies, 3, 'node page topic must parse non-zero reply count')

assert.match(apiSource, /normalizeNodeTopics\s*\(/, 'getNodeTopicsPage must normalize node identity onto node-page topics before TopicCard renders')
assert.match(apiSource, /name:\s*nodeName|name:\s*clean/, 'node topic normalization must populate node.name from the current /go/{node} route')
assert.match(apiSource, /title:\s*nodeTitle|title:\s*clean/, 'node topic normalization must populate node.title so NodeTag is not blank')

console.log('node topic list parser contract passed')
