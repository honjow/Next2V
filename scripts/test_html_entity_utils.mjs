#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function decodeHtmlEntities(value) {
  if (!value) return ''
  let decoded = value
  for (let i = 0; i < 2; i++) {
    const next = decoded
      .replace(/&quot;/g, '"')
      .replace(/&#34;/g, '"')
      .replace(/&#x22;/gi, '"')
      .replace(/&#39;/g, "'")
      .replace(/&#x27;/gi, "'")
      .replace(/&apos;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&#60;/g, '<')
      .replace(/&#x3c;/gi, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#62;/g, '>')
      .replace(/&#x3e;/gi, '>')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#160;/g, ' ')
      .replace(/&#xa0;/gi, ' ')
      .replace(/&amp;/g, '&')
    if (next === decoded) break
    decoded = next
  }
  return decoded
}

const cases = [
  ['他说 &quot;可以&quot;，然后继续', '他说 "可以"，然后继续'],
  ['我让 codex 帮我调试，结束时突然来了个&quot;亚洲 AV&quot;，不知道哪里出问题了。', '我让 codex 帮我调试，结束时突然来了个"亚洲 AV"，不知道哪里出问题了。'],
  ['Tom &amp; Jerry', 'Tom & Jerry'],
  ['&amp;quot;double encoded&amp;quot;', '"double encoded"'],
  ['1 &lt; 2 &amp;&amp; 3 &gt; 2', '1 < 2 && 3 > 2'],
  ['A&nbsp;B&#160;C', 'A B C'],
  ['It&#39;s &apos;fine&apos;', "It's 'fine'"]
]

for (const [input, expected] of cases) {
  const actual = decodeHtmlEntities(input)
  if (actual !== expected) {
    console.error(`FAIL: ${input}\n  expected: ${expected}\n  actual:   ${actual}`)
    process.exit(1)
  }
}

function normalizeTopic(topic) {
  if (!topic) return topic
  topic.title = decodeHtmlEntities(topic.title)
  topic.content = decodeHtmlEntities(topic.content)
  topic.content_rendered = decodeHtmlEntities(topic.content_rendered)
  return topic
}

function normalizeReply(reply) {
  if (!reply) return reply
  reply.content = decodeHtmlEntities(reply.content)
  reply.content_rendered = decodeHtmlEntities(reply.content_rendered)
  return reply
}

const normalizeCases = [
  {
    name: 'topic content_rendered decodes &quot;',
    actual: normalizeTopic({ title: 't', content: 'c', content_rendered: '<p>&quot;亚洲 AV&quot;</p>' }).content_rendered,
    expected: '<p>"亚洲 AV"</p>'
  },
  {
    name: 'topic content_rendered decodes &amp;quot;',
    actual: normalizeTopic({ title: 't', content: 'c', content_rendered: '<p>&amp;quot;亚洲 AV&amp;quot;</p>' }).content_rendered,
    expected: '<p>"亚洲 AV"</p>'
  },
  {
    name: 'reply content_rendered decodes &quot;',
    actual: normalizeReply({ content: 'c', content_rendered: '<span>&quot;亚洲 AV&quot;</span>' }).content_rendered,
    expected: '<span>"亚洲 AV"</span>'
  },
  {
    name: 'reply content_rendered decodes &amp;quot;',
    actual: normalizeReply({ content: 'c', content_rendered: '<span>&amp;quot;亚洲 AV&amp;quot;</span>' }).content_rendered,
    expected: '<span>"亚洲 AV"</span>'
  },
  {
    name: 'undefined content_rendered remains empty-string compatible',
    actual: normalizeTopic({ title: '', content: '', content_rendered: undefined }).content_rendered,
    expected: ''
  }
]

for (const { name, actual, expected } of normalizeCases) {
  if (actual !== expected) {
    console.error(`FAIL: ${name}\n  expected: ${expected}\n  actual:   ${actual}`)
    process.exit(1)
  }
}

function assertProductionNormalizeCoverage(filePath, serviceName) {
  const source = readFileSync(new URL(`../${filePath}`, import.meta.url), 'utf8')
  const topicMethod = source.match(/private static normalizeTopic\([\s\S]*?\n  }/)
  const replyMethod = source.match(/private static normalizeReply\([\s\S]*?\n  }/)
  const required = [
    {
      name: `${serviceName}.normalizeTopic decodes content_rendered`,
      method: topicMethod?.[0] || '',
      line: 'topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)'
    },
    {
      name: `${serviceName}.normalizeReply decodes content_rendered`,
      method: replyMethod?.[0] || '',
      line: 'reply.content_rendered = HtmlEntityUtils.decode(reply.content_rendered)'
    }
  ]

  for (const { name, method, line } of required) {
    if (!method.includes(line)) {
      console.error(`FAIL: production coverage missing: ${name}\n  expected line: ${line}\n  file: ${filePath}`)
      process.exit(1)
    }
  }
}

function assertFavoriteDetailRenderPathCoverage() {
  const detailFilePath = 'feature/detail/src/main/ets/viewmodel/DetailViewModel.ets'
  const detailSource = readFileSync(new URL(`../${detailFilePath}`, import.meta.url), 'utf8')
  const markdownFilePath = 'shared/src/main/ets/components/MarkdownContent.ets'
  const markdownSource = readFileSync(new URL(`../${markdownFilePath}`, import.meta.url), 'utf8')
  const required = [
    {
      name: 'favorite TopicDetail cached topic is normalized before render',
      filePath: detailFilePath,
      source: detailSource,
      line: 'this.topic = this.normalizeTopicForRender(cached.topic)'
    },
    {
      name: 'favorite TopicDetail network topic is normalized before render',
      filePath: detailFilePath,
      source: detailSource,
      line: 'this.topic = this.normalizeTopicForRender(topic)'
    },
    {
      name: 'favorite TopicDetail render boundary decodes Markdown content',
      filePath: detailFilePath,
      source: detailSource,
      line: 'topic.content = HtmlEntityUtils.decode(topic.content)'
    },
    {
      name: 'favorite TopicDetail render boundary decodes content_rendered cache/API field',
      filePath: detailFilePath,
      source: detailSource,
      line: 'topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)'
    },
    {
      name: 'Markdown text span boundary decodes lexer-emitted entities before visible Text/Span rendering',
      filePath: markdownFilePath,
      source: markdownSource,
      line: '_splitMentionText(HtmlEntityUtils.decode(text))'
    }
  ]

  for (const { name, filePath, source, line } of required) {
    if (!source.includes(line)) {
      console.error(`FAIL: favorite detail path coverage missing: ${name}\n  expected line: ${line}\n  file: ${filePath}`)
      process.exit(1)
    }
  }
}

assertProductionNormalizeCoverage('shared/src/main/ets/network/ApiService.ets', 'ApiService')
assertProductionNormalizeCoverage('shared/src/main/ets/network/ApiV2Service.ets', 'ApiV2Service')
assertFavoriteDetailRenderPathCoverage()

console.log(`PASS: ${cases.length} HTML entity decode cases; ${normalizeCases.length} normalize content_rendered cases; production normalize coverage asserted for V1/V2 and favorite TopicDetail render path`)
