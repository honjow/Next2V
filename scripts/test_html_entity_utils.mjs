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

// --- Render-path invariant -------------------------------------------------
// content_rendered is HTML. Its &lt;/&gt;/&amp; entities ARE the markup. Angle
// brackets that belong to the *displayed text* (anchor labels like
// &lt;&lt;title&gt;&gt;) only survive while encoded. The renderers must therefore
// receive raw HTML and decode entities at the text LEAVES — after real tags are
// stripped — never up-front at the network layer. These cases mirror
// MarkdownContent.stripHtmlTags / appendHtmlTextToken: strip real `<...>` tags,
// THEN decode entities.
function stripHtmlTagsThenDecode(value) {
  return decodeHtmlEntities((value || '').replace(/<[^>]+>/g, '')).replace(/[ \t\f\v]+/g, ' ').trim()
}

const renderLeafCases = [
  {
    // Real bytes from V2EX topic 1188918 content_rendered: an anchor whose label
    // is an entity-encoded title. The title must survive in full, not collapse to '>'.
    name: 'entity-encoded angle-bracket anchor title survives leaf strip',
    input: '<a href="https://www.v2ex.com/t/1188728" rel="nofollow">&lt;&lt;一个大胆的预言：语音输入将成为绝对主流&gt;&gt;</a>',
    expected: '<<一个大胆的预言：语音输入将成为绝对主流>>'
  },
  {
    name: 'quoted-title anchor survives leaf strip',
    input: '<a href="x" rel="nofollow">&lt;&lt;"AI 与编程" 几个月来高强度 vibe coding 的一点心得&gt;&gt;</a>',
    expected: '<<"AI 与编程" 几个月来高强度 vibe coding 的一点心得>>'
  },
  {
    // The case the old network-layer decode was added to fix — STILL works,
    // because the leaf decode handles it. Proves keeping raw loses nothing.
    name: '&quot; in paragraph text still decodes at the leaf',
    input: '&quot;亚洲 AV&quot;',
    expected: '"亚洲 AV"'
  },
  {
    name: 'double-encoded &amp;quot; still decodes at the leaf',
    input: '&amp;quot;亚洲 AV&amp;quot;',
    expected: '"亚洲 AV"'
  }
]

for (const { name, input, expected } of renderLeafCases) {
  const actual = stripHtmlTagsThenDecode(input)
  if (actual !== expected) {
    console.error(`FAIL: ${name}\n  expected: ${expected}\n  actual:   ${actual}`)
    process.exit(1)
  }
}

// Counter-proof: if content_rendered is decoded BEFORE the leaf strip (the retired
// bug), the same anchor collapses to a bare '>' because <一个大胆…> now looks like a
// real tag. This documents WHY the network layer must keep content_rendered raw.
const preDecodedThenStripped = stripHtmlTagsThenDecode(
  decodeHtmlEntities('<a href="x">&lt;&lt;一个大胆的预言&gt;&gt;</a>')
)
if (preDecodedThenStripped !== '>') {
  console.error(
    `FAIL: counter-proof drifted — pre-decoding should corrupt the title to '>'\n  actual: ${preDecodedThenStripped}`
  )
  process.exit(1)
}

// --- Production coverage ----------------------------------------------------
// The network normalize layer must decode title/content (plain-text fields) but
// must NOT decode content_rendered (HTML); the latter stays raw for the renderers.
function methodBody(source, methodName) {
  const m = source.match(new RegExp(`private static ${methodName}\\([\\s\\S]*?\\n  }`))
  return m?.[0] || ''
}

function assertNetworkKeepsContentRenderedRaw(filePath, serviceName, opts) {
  const source = readFileSync(new URL(`../${filePath}`, import.meta.url), 'utf8')
  const checks = []
  if (opts.topic) {
    const body = methodBody(source, 'normalizeTopic')
    checks.push({
      name: `${serviceName}.normalizeTopic keeps content_rendered raw`,
      ok: body.length > 0 && !body.includes('content_rendered = HtmlEntityUtils.decode'),
      detail: 'content_rendered must NOT be decoded at the network layer'
    })
    checks.push({
      name: `${serviceName}.normalizeTopic still decodes plain-text content`,
      ok: body.includes('topic.content = HtmlEntityUtils.decode(topic.content)'),
      detail: 'plain-text content must still be decoded'
    })
  }
  if (opts.reply) {
    const body = methodBody(source, 'normalizeReply')
    checks.push({
      name: `${serviceName}.normalizeReply keeps content_rendered raw`,
      ok: body.length > 0 && !body.includes('content_rendered = HtmlEntityUtils.decode'),
      detail: 'content_rendered must NOT be decoded at the network layer'
    })
    checks.push({
      name: `${serviceName}.normalizeReply still decodes plain-text content`,
      ok: body.includes('reply.content = HtmlEntityUtils.decode(reply.content)'),
      detail: 'plain-text content must still be decoded'
    })
  }
  for (const { name, ok, detail } of checks) {
    if (!ok) {
      console.error(`FAIL: production coverage: ${name}\n  ${detail}\n  file: ${filePath}`)
      process.exit(1)
    }
  }
}

function assertDetailRenderPathCoverage() {
  const detailFilePath = 'feature/detail/src/main/ets/viewmodel/DetailViewModel.ets'
  const detailSource = readFileSync(new URL(`../${detailFilePath}`, import.meta.url), 'utf8')
  const markdownFilePath = 'shared/src/main/ets/components/MarkdownContent.ets'
  const markdownSource = readFileSync(new URL(`../${markdownFilePath}`, import.meta.url), 'utf8')
  const required = [
    {
      name: 'TopicDetail render boundary decodes plain-text Markdown content',
      filePath: detailFilePath,
      source: detailSource,
      present: 'topic.content = HtmlEntityUtils.decode(topic.content)'
    },
    {
      // Render boundary must NOT decode content_rendered — that is the retired bug.
      name: 'TopicDetail render boundary keeps content_rendered raw',
      filePath: detailFilePath,
      source: detailSource,
      absent: 'topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)'
    },
    {
      name: 'Markdown text span boundary decodes lexer-emitted entities before visible Text/Span rendering',
      filePath: markdownFilePath,
      source: markdownSource,
      present: '_splitMentionText(HtmlEntityUtils.decode(text))'
    }
  ]

  for (const { name, filePath, source, present, absent } of required) {
    if (present && !source.includes(present)) {
      console.error(`FAIL: detail render path coverage missing: ${name}\n  expected line: ${present}\n  file: ${filePath}`)
      process.exit(1)
    }
    if (absent && source.includes(absent)) {
      console.error(`FAIL: detail render path regression: ${name}\n  must NOT contain: ${absent}\n  file: ${filePath}`)
      process.exit(1)
    }
  }
}

assertNetworkKeepsContentRenderedRaw('shared/src/main/ets/network/ApiService.ets', 'ApiService', { topic: true, reply: true })
assertNetworkKeepsContentRenderedRaw('shared/src/main/ets/network/ApiV2Service.ets', 'ApiV2Service', { topic: true, reply: true })
assertNetworkKeepsContentRenderedRaw('shared/src/main/ets/network/V2exTopicWebRepliesClient.ets', 'V2exTopicWebRepliesClient', { reply: true })
assertDetailRenderPathCoverage()

console.log(
  `PASS: ${cases.length} HTML entity decode cases; ${renderLeafCases.length} render-leaf cases + angle-bracket counter-proof; ` +
  `content_rendered-stays-raw asserted for ApiService/ApiV2Service/V2exTopicWebRepliesClient and the TopicDetail render path`
)
