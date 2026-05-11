#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const sampleHtml = readFileSync(new URL('./fixtures/topic_1212003_replies_sample.html', import.meta.url), 'utf8')

function decodeHtml(value) {
  return (value || '')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
}

function parseNumber(value) {
  const parsed = Number.parseInt(value || '0', 10)
  return Number.isFinite(parsed) ? parsed : 0
}

function extractAttr(tag, name) {
  const re = new RegExp(`${name}=['"]([^'"]*)['"]`, 'i')
  const m = (tag || '').match(re)
  return m?.[1] ? decodeHtml(m[1]) : ''
}

function markdown(html) {
  return decodeHtml((html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>\s*<p[^>]*>/gi, '\n\n')
    .replace(/<p[^>]*>/gi, '')
    .replace(/<\/p>/gi, '')
    .replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '\n```\n$1\n```\n')
    .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function parseReplies(html) {
  const replies = []
  const replyRe = /<div\s+id=['"]r_(\d+)['"][^>]*class=['"][^'"]*\bcell\b[^'"]*['"][^>]*>([\s\S]*?)(?=<div\s+id=['"]r_\d+['"][^>]*class=['"][^'"]*\bcell\b|<div\s+class=['"]sep20['"]|$)/gi
  let m = replyRe.exec(html)
  while (m) {
    const id = parseNumber(m[1])
    const block = m[2] || ''
    const contentRendered = block.match(/<div[^>]*class=['"][^'"]*\breply_content\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i)?.[1]?.trim() || ''
    const avatarTag = block.match(/<img[^>]+class=['"][^'"]*\bavatar\b[^'"]*['"][^>]*>/i)?.[0] || ''
    const username = block.match(/<a[^>]+href=['"]\/member\/([^'"]+)['"][^>]*>/i)?.[1] || extractAttr(avatarTag, 'alt')
    replies.push({ id, content: markdown(contentRendered), content_rendered: contentRendered, member: { id: parseNumber(extractAttr(avatarTag, 'data-uid')), username, avatar_normal: extractAttr(avatarTag, 'src') } })
    m = replyRe.exec(html)
  }
  return replies
}

const replies = parseReplies(sampleHtml)
if (replies.length !== 12) {
  console.error(`FAIL: expected 12 parsed web replies, got ${replies.length}`)
  process.exit(1)
}

const linkReply = replies[1]
if (linkReply.id !== 17627699 || linkReply.member.username !== 'zrc' || !linkReply.content.includes('[business.google.com](http://business.google.com)')) {
  console.error('FAIL: parsed id/member/link content is wrong', linkReply)
  process.exit(1)
}

const mentionReply = replies[4]
if (!mentionReply.content.includes('[@zrc](/member/zrc)')) {
  console.error('FAIL: member mention was not converted to markdown', mentionReply.content)
  process.exit(1)
}

function assertProductionCoverage() {
  const parserPath = 'shared/src/main/ets/parser/V2exTopicRepliesParser.ets'
  const apiPath = 'shared/src/main/ets/network/ApiService.ets'
  const detailPath = 'feature/detail/src/main/ets/viewmodel/DetailViewModel.ets'
  const indexPath = 'shared/src/main/ets/Index.ets'
  const parser = readFileSync(new URL(`../${parserPath}`, import.meta.url), 'utf8')
  const api = readFileSync(new URL(`../${apiPath}`, import.meta.url), 'utf8')
  const detail = readFileSync(new URL(`../${detailPath}`, import.meta.url), 'utf8')
  const index = readFileSync(new URL(`../${indexPath}`, import.meta.url), 'utf8')

  const required = [
    [parserPath, parser, 'export class V2exTopicRepliesParser'],
    [parserPath, parser, 'static parseReplies(html: string): V2exReply[]'],
    [parserPath, parser, 'id=[\'\"]r_(\\d+)'],
    [apiPath, api, 'async getRepliesWithWebFallback(topicId: number, expectedReplies: number = 0): Promise<V2exReply[]>'],
    [apiPath, api, 'apiReplies.length === 0 || (expectedReplies > 0 && apiReplies.length < expectedReplies)'],
    [apiPath, api, 'const webReplies = await this.getTopicWebReplies(topicId)'],
    [apiPath, api, 'V2exTopicRepliesParser.parseReplies'],
    [apiPath, api, '`/t/${topicId}?p=1&_=${cacheBuster}`'],
    [detailPath, detail, 'replies = await this.api.getRepliesWithWebFallback(this.topicId, topic ? topic.replies : 0)'],
    [detailPath, detail, 'const replyRes = await this.apiV2.getTopicReplies(this.authToken, this.topicId, 1)'],
    [indexPath, index, "export { V2exTopicRepliesParser } from './parser/V2exTopicRepliesParser'"]
  ]

  for (const [file, source, needle] of required) {
    if (!source.includes(needle)) {
      console.error(`FAIL: missing production coverage in ${file}: ${needle}`)
      process.exit(1)
    }
  }
}

assertProductionCoverage()
console.log('PASS: topic web replies parser regression and production coverage')
