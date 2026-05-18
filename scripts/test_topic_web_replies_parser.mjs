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

function decodeCloudflareEmail(cfemail) {
  const value = (cfemail || '').trim()
  if (value.length < 4 || value.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(value)) {
    return ''
  }
  const key = Number.parseInt(value.slice(0, 2), 16)
  if (Number.isNaN(key)) {
    return ''
  }
  let result = ''
  for (let i = 2; i < value.length; i += 2) {
    const byteValue = Number.parseInt(value.slice(i, i + 2), 16)
    if (Number.isNaN(byteValue)) {
      return ''
    }
    result += String.fromCharCode(byteValue ^ key)
  }
  return result
}

function cloudflareEmailToText(anchor) {
  return decodeCloudflareEmail(extractAttr(anchor, 'data-cfemail')) || anchor.replace(/<[^>]+>/g, '')
}

function markdown(html) {
  return decodeHtml((html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>\s*<p[^>]*>/gi, '\n\n')
    .replace(/<p[^>]*>/gi, '')
    .replace(/<\/p>/gi, '')
    .replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '\n```\n$1\n```\n')
    .replace(/<a\b[^>]*class=['"][^'"]*\b__cf_email__\b[^'"]*['"][^>]*>[\s\S]*?<\/a>/gi,
      match => cloudflareEmailToText(match))
    .replace(/@?\s*<a[^>]+href=['"]\/member\/([0-9A-Za-z_]+)['"][^>]*>[\s\S]*?<\/a>/gi, '[@$1](/member/$1)')
    .replace(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function removeReplyContentHtml(block) {
  return (block || '').replace(/<div[^>]*class=['"][^'"]*\breply_content\b[^'"]*['"][^>]*>[\s\S]*?<\/div>/gi, '')
}

function extractThanks(block) {
  const metaBlock = removeReplyContentHtml(block || '')
  const heartCount = metaBlock.match(/<span[^>]*class=['"][^'"]*\bsmall\b[^'"]*\bfade\b[^'"]*['"][^>]*>[\s\S]*?(?:heart|❤️)[\s\S]*?(\d+)\s*<\/span>/i)
  if (heartCount?.[1]) {
    return parseNumber(heartCount[1])
  }
  const m = metaBlock.match(/(\d+)\s*(?:个)?感谢|thanks[^>]*>\s*(\d+)/i)
  return m ? parseNumber(m[1] || m[2] || '') : 0
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
    replies.push({ id, thanks: extractThanks(block), content: markdown(contentRendered), content_rendered: contentRendered, member: { id: parseNumber(extractAttr(avatarTag, 'data-uid')), username, avatar_normal: extractAttr(avatarTag, 'src') } })
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

const topic1213489Reply35Html = `
<div id="r_17653398" class="cell">
  <table><tr>
    <td><img src="https://cdn.v2ex.com/avatar/bca5/444b/205319_normal.png?m=1748934526" class="avatar" alt="u3u" data-uid="205319" /></td>
    <td><strong><a href="/member/u3u" class="dark">u3u</a></strong>
      <div class="reply_content"><a target="_blank" href="https://i.imgur.com/vL7eAiI.png" rel="nofollow noopener" target="_blank"><img src="https://i.imgur.com/vL7eAiI.png" class="embedded_image" rel="noreferrer"></a><br /><a target="_blank" href="https://i.imgur.com/8wpc4J1.png" rel="nofollow noopener" target="_blank"><img src="https://i.imgur.com/8wpc4J1.png" class="embedded_image" rel="noreferrer"></a><br />@<a href="/member/Livid">Livid</a> #26 这个错误之前也偶尔出现过 但一般换一下节点就可以了 今天是所有节点都无法访问 我给 <a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="84f7f1f4f4ebf6f0c4f2b6e1fcaae7ebe9">[email&#160;protected]</a> 发了邮件 目前只有 <a target="_blank" href="http://global.v2ex.co" rel="nofollow noopener">global.v2ex.co</a> 域名可以正常访问</div>
    </td>
  </tr></table>
</div>`
const topic1213489Replies = parseReplies(topic1213489Reply35Html)
const topic1213489Reply35 = topic1213489Replies[0]
if (!topic1213489Reply35 || !topic1213489Reply35.content.includes('support@v2ex.com')) {
  console.error('FAIL: Cloudflare protected email was not decoded in topic 1213489 reply 35', topic1213489Reply35)
  process.exit(1)
}
if (topic1213489Reply35.content.includes('/cdn-cgi/l/email-protection')) {
  console.error('FAIL: Cloudflare email protection URL leaked into markdown content', topic1213489Reply35.content)
  process.exit(1)
}

const topic1213451Reply20Html = `
<div id="r_17652152" class="cell">
  <table><tr>
    <td><img src="https://cdn.v2ex.com/avatar/a46a/cf27/384005_normal.png?m=1689697711" class="avatar" alt="cherishd" data-uid="384005" /></td>
    <td><div class="fr">&nbsp; &nbsp;<span class="no">20</span></div>
      <strong><a href="/member/cherishd" class="dark">cherishd</a></strong>
      <span class="ago" title="2026-05-18 11:54:12 +08:00">几小时前</span>
      <div class="reply_content">ID：290  感谢老板<br /><br />YTE5ODU5NjQwOThAb3V0bG9vay5jb20=</div>
    </td>
  </tr></table>
</div>`
const topic1213451Reply20 = parseReplies(topic1213451Reply20Html)[0]
if (!topic1213451Reply20 || topic1213451Reply20.thanks !== 0) {
  console.error('FAIL: topic 1213451 reply 20 body text was parsed as thanks', topic1213451Reply20)
  process.exit(1)
}
if (!topic1213451Reply20.content.includes('ID：290')) {
  console.error('FAIL: topic 1213451 reply 20 content was damaged while extracting thanks', topic1213451Reply20)
  process.exit(1)
}

const thankedReplyHtml = `
<div id="r_1" class="cell">
  <table><tr>
    <td><img src="https://cdn.v2ex.com/avatar/test_normal.png" class="avatar" alt="member" data-uid="1" /></td>
    <td><div class="fr"><span class="small fade">heart 3</span></div>
      <strong><a href="/member/member" class="dark">member</a></strong>
      <div class="reply_content">正文无感谢数</div>
    </td>
  </tr></table>
</div>`
const thankedReply = parseReplies(thankedReplyHtml)[0]
if (!thankedReply || thankedReply.thanks !== 3) {
  console.error('FAIL: metadata thanks count was not parsed', thankedReply)
  process.exit(1)
}

function assertProductionCoverage() {
  const parserPath = 'shared/src/main/ets/parser/V2exTopicRepliesParser.ets'
  const apiPath = 'shared/src/main/ets/network/ApiService.ets'
  const webRepliesClientPath = 'shared/src/main/ets/network/V2exTopicWebRepliesClient.ets'
  const detailPath = 'feature/detail/src/main/ets/viewmodel/DetailViewModel.ets'
  const indexPath = 'shared/src/main/ets/Index.ets'
  const parser = readFileSync(new URL(`../${parserPath}`, import.meta.url), 'utf8')
  const api = readFileSync(new URL(`../${apiPath}`, import.meta.url), 'utf8')
  const webRepliesClient = readFileSync(new URL(`../${webRepliesClientPath}`, import.meta.url), 'utf8')
  const detail = readFileSync(new URL(`../${detailPath}`, import.meta.url), 'utf8')
  const index = readFileSync(new URL(`../${indexPath}`, import.meta.url), 'utf8')

  const required = [
    [parserPath, parser, 'export class V2exTopicRepliesParser'],
    [parserPath, parser, 'static parseReplies(html: string): V2exReply[]'],
    [parserPath, parser, 'id=[\'\"]r_(\\d+)'],
    [parserPath, parser, 'cloudflareEmailToText'],
    [parserPath, parser, 'decodeCloudflareEmail'],
    [parserPath, parser, 'data-cfemail'],
    [parserPath, parser, 'thanks: V2exTopicRepliesParser.extractThanks(block)'],
    [parserPath, parser, 'removeReplyContentHtml'],
    [apiPath, api, 'async getRepliesWithWebFallback('],
    [apiPath, api, 'expectedReplies: number = 0'],
    [apiPath, api, 'apiReplies.length === 0 || (expectedReplies > 0 && apiReplies.length < expectedReplies)'],
    [apiPath, api, 'const webReplies = await this.getTopicWebReplies(topicId)'],
    [apiPath, api, 'return this.topicWebRepliesClient().getPage(topicId, page, cacheBuster, cookie)'],
    [webRepliesClientPath, webRepliesClient, 'export class V2exTopicWebRepliesClient'],
    [webRepliesClientPath, webRepliesClient, 'V2exTopicRepliesParser.parseReplies'],
    [webRepliesClientPath, webRepliesClient, 'const path = `/t/${topicId}?p=${safePage}&_=${cacheBuster}`'],
    [detailPath, detail, 'const firstPage = await this.api.getTopicWebRepliesPage('],
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
