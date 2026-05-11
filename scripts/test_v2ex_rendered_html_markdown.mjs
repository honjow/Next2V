#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

function decodeHtml(value) {
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

function stripTags(value) {
  return decodeHtml(value.replace(/<[^>]+>/g, ''))
    .replace(/[ \t\f\v]+/g, ' ')
    .trim()
}

function attr(tag, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i')
  const m = tag.match(re)
  return m ? decodeHtml(m[2]) : ''
}

function inlineHtmlToMarkdown(value) {
  return (value || '')
    .replace(/<img\b[^>]*>/gi, tag => {
      const src = attr(tag, 'src')
      const alt = attr(tag, 'alt')
      return src ? `![${alt}](${src})` : ''
    })
    .replace(/<a\b[^>]*href=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi, (_all, _quote, href, text) => {
      const label = stripTags(text)
      const url = decodeHtml(href).trim()
      if (!url) return label
      return label && label !== url ? `[${label}](${url})` : url
    })
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<code\b[^>]*>([\s\S]*?)<\/code>/gi, (_all, code) => `\`${stripTags(code)}\``)
    .replace(/<(strong|b)\b[^>]*>([\s\S]*?)<\/\1>/gi, (_all, _tag, text) => `**${stripTags(text)}**`)
    .replace(/<(em|i)\b[^>]*>([\s\S]*?)<\/\1>/gi, (_all, _tag, text) => `*${stripTags(text)}*`)
    .replace(/<[^>]+>/g, '')
}

function convertHtmlTable(tableHtml) {
  const rows = []
  let rowMatch
  const rowRe = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi
  while ((rowMatch = rowRe.exec(tableHtml))) {
    const cells = []
    let cellMatch
    const cellRe = /<t[hd]\b[^>]*>([\s\S]*?)<\/t[hd]>/gi
    while ((cellMatch = cellRe.exec(rowMatch[1]))) {
      cells.push(inlineHtmlToMarkdown(cellMatch[1]).replace(/\s*\n\s*/g, ' ').replace(/\|/g, '\\|').trim())
    }
    if (cells.length > 0) rows.push(cells)
  }
  if (rows.length === 0) return ''
  const width = Math.max(...rows.map(row => row.length))
  const pad = row => Array.from({ length: width }, (_, i) => row[i] || '')
  const lines = [`| ${pad(rows[0]).join(' | ')} |`, `| ${Array(width).fill('---').join(' | ')} |`]
  for (const row of rows.slice(1)) lines.push(`| ${pad(row).join(' | ')} |`)
  return `\n\n${lines.join('\n')}\n\n`
}

function convertList(html, ordered) {
  const items = []
  let match
  const re = /<li\b[^>]*>([\s\S]*?)<\/li>/gi
  while ((match = re.exec(html))) {
    const text = inlineHtmlToMarkdown(match[1]).replace(/\s*\n\s*/g, ' ').trim()
    if (text) items.push(text)
  }
  return `\n\n${items.map((item, i) => `${ordered ? `${i + 1}.` : '-'} ${item}`).join('\n')}\n\n`
}

function renderedHtmlToMarkdown(input) {
  let md = input
    .replace(/\r\n/g, '\n')
    .replace(/<table\b[^>]*>[\s\S]*?<\/table>/gi, table => convertHtmlTable(table))
    .replace(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi, (_all, level, text) => `\n\n${'#'.repeat(Number(level))} ${stripTags(text)}\n\n`)
    .replace(/<ol\b[^>]*>([\s\S]*?)<\/ol>/gi, (_all, body) => convertList(body, true))
    .replace(/<ul\b[^>]*>([\s\S]*?)<\/ul>/gi, (_all, body) => convertList(body, false))
    .replace(/<p\b[^>]*>([\s\S]*?)<\/p>/gi, (_all, text) => `\n\n${inlineHtmlToMarkdown(text).trim()}\n\n`)
    .replace(/<div\b[^>]*>/gi, '\n\n')
    .replace(/<\/div>/gi, '\n\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<img\b[^>]*>/gi, tag => inlineHtmlToMarkdown(tag))
    .replace(/<[^>]+>/g, '')
  return decodeHtml(md).replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim()
}

const casbinSnippet = `<div class="markdown_body"><h2>Casbin 明日之星预选生计划-Talent for Casbin 2026</h2>
<p>2020 年，Casbin 参加了<a href="https://summerofcode.withgoogle.com/archive/2020/organizations/6587176113930240/" rel="nofollow">Google Summer of Code 2020</a>。</p>
<table><thead><tr><th>活动</th><th>学生人数</th><th>最终考核通过人数</th></tr></thead><tbody><tr><td>GSoC</td><td>4</td><td>4</td></tr></tbody></table>
<ul><li>积极参与开源社区的建设，参与代码提交、解决 Issue 、审核 PR 等日常工作；</li></ul>
<div><img alt="qrcode-casbin" class="embedded_image" src="https://cdn.casbin.com/activity/qrcode-casbin.png"/></div></div>`

const out = renderedHtmlToMarkdown(casbinSnippet)
assert.match(out, /^## Casbin 明日之星预选生计划-Talent for Casbin 2026/m)
assert.match(out, /\[Google Summer of Code 2020\]\(https:\/\/summerofcode\.withgoogle\.com\/archive\/2020\/organizations\/6587176113930240\/\)/)
assert.match(out, /\| 活动 \| 学生人数 \| 最终考核通过人数 \|/)
assert.match(out, /\| GSoC \| 4 \| 4 \|/)
assert.match(out, /^- 积极参与开源社区的建设/m)
assert.match(out, /!\[qrcode-casbin\]\(https:\/\/cdn\.casbin\.com\/activity\/qrcode-casbin\.png\)/)
assert.doesNotMatch(out, /<\/?(?:div|h2|p|table|ul|li|img)\b/i)

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
assert.match(source, /renderedHtmlToMarkdown/)
assert.match(source, /convertHtmlTable/)
assert.match(source, /looksLikeRenderedHtml/)

console.log('v2ex rendered html markdown regression checks passed')
