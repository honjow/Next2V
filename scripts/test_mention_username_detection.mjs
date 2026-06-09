#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

function isMentionNameChar(ch) {
  return /[0-9A-Za-z_]/.test(ch)
}

function isMentionBoundaryChar(ch) {
  if (!ch) return true
  return !isMentionNameChar(ch) && ch !== '-' && ch !== '.'
}

function isValidMentionMatch(raw, atIndex, matchText) {
  const before = atIndex > 0 ? raw.charAt(atIndex - 1) : ''
  const afterIndex = atIndex + matchText.length
  const after = afterIndex < raw.length ? raw.charAt(afterIndex) : ''
  return isMentionBoundaryChar(before) && isMentionBoundaryChar(after)
}

function extractMentionedUsernames(content, renderedContent = '') {
  const names = []
  const seen = new Set()
  const addName = (name) => {
    const clean = (name || '').trim()
    const key = clean.toLowerCase()
    if (clean && !seen.has(key)) {
      seen.add(key)
      names.push(clean)
    }
  }

  const linkRe = /@\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
  let linkMatch = linkRe.exec(renderedContent || '')
  while (linkMatch) {
    addName(linkMatch[1] || '')
    linkMatch = linkRe.exec(renderedContent || '')
  }
  if (names.length > 0) return names

  const re = /@([0-9A-Za-z_]{2,32})/g
  let m = re.exec(content || '')
  while (m) {
    if (isValidMentionMatch(content || '', m.index, m[0])) addName(m[1] || '')
    m = re.exec(content || '')
  }
  return names
}

function splitMentionText(text) {
  const raw = text || ''
  if (!raw) return ['']
  const parts = []
  const re = /@([0-9A-Za-z_]{2,32})/g
  let last = 0
  let m = re.exec(raw)
  while (m) {
    const matchText = m[0]
    if (!isValidMentionMatch(raw, m.index, matchText)) {
      m = re.exec(raw)
      continue
    }
    if (m.index > last) parts.push(raw.slice(last, m.index))
    parts.push(matchText)
    last = m.index + matchText.length
    m = re.exec(raw)
  }
  if (last < raw.length) parts.push(raw.slice(last))
  return parts.length > 0 ? parts : [raw]
}

const renderedReply = '@<a href="/member/AIXAPI">AIXAPI</a> 感谢推荐，有几个问题咨询大佬：<br /><br />quant-analysis@quant-skills 这个是聚宽的 skills?<br /><br />web-search@browser-skills 这个需要 token 吗？'
const rawReply = '@AIXAPI 感谢推荐，有几个问题咨询大佬：\n\nquant-analysis@quant-skills 这个是聚宽的 skills?\n\nweb-search@browser-skills 这个需要 token 吗？'
assert.deepEqual(extractMentionedUsernames(rawReply, renderedReply), ['AIXAPI'])

const skillsOnly = 'quant-analysis@quant-skills portfolio-tracker@finance-dev web-search@browser-skills obsidian-publisher@obsidian-tools'
assert.deepEqual(extractMentionedUsernames(skillsOnly), [])
assert.deepEqual(splitMentionText(skillsOnly), [skillsOnly])

assert.deepEqual(extractMentionedUsernames('谢谢 @jackdan9 推荐'), ['jackdan9'])
assert.deepEqual(splitMentionText('@jackdan9 感谢推荐'), ['@jackdan9', ' 感谢推荐'])
assert.deepEqual(extractMentionedUsernames('mail me at test@example.com'), [])

const markdownSource = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
assert.match(markdownSource, /function _isValidMentionMatch/)
assert.match(markdownSource, /_isValidMentionMatch\(raw, m\.index, matchText\)/)

// The mention-extraction logic was extracted out of TopicDetailPage into a dedicated
// coordinator (ReplyContextCoordinator). Same intent: prefer V2EX /member/ links inside
// content_rendered, then fall back to boundary-validated @name plain-text matches. The loop
// cursor variable was renamed m -> match during the move.
const detailSource = readFileSync('feature/detail/src/main/ets/model/ReplyContextCoordinator.ets', 'utf8')
assert.match(detailSource, /content_rendered/)
assert.match(detailSource, /\\\/member\\\//)
assert.match(detailSource, /isValidMentionMatch\(raw, match\.index, match\[0\]\)/)

console.log('PASS: mention username detection avoids skill/email false positives and uses V2EX member links')
